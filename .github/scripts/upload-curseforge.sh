#!/usr/bin/env bash
# Uploads a checked release zip to CurseForge, filed under WoW Forever. The
# endpoint and payload are the BigWigs packager's (upload_curseforge at the
# pinned commit); the packager uploads only a zip it builds in the same run,
# so the checks could not come before its upload.
#
# Usage: upload-curseforge.sh [--dry-run] <zip> <notes.md>
# The token comes from CF_API_TOKEN and is never printed.
# --dry-run resolves the game version and builds the payload, uploads nothing;
# without a token it takes the version from the TOC and the ID 0.
# For the CI controls only, with --dry-run: CF_VERSIONS_FILE replaces the
# site's version list, GAME_VERSION the version the TOC asks for.
set -euo pipefail
. "$(dirname "$0")/lib-forever.sh"

dry=""
if [ "${1:-}" = --dry-run ]; then dry=1; shift; fi
zip="$1"
notes="$2"

api="https://wow.curseforge.com/api"
forever_type=88568 # CurseForge's game version type for WoW Forever

if [ -z "$dry" ] && [ -n "${CF_VERSIONS_FILE:-}${GAME_VERSION:-}" ]; then
    fail "CF_VERSIONS_FILE and GAME_VERSION are for dry runs only"
fi

project=$(toc_field X-Curse-Project-ID)
[[ "$project" =~ ^[0-9]+$ ]] || fail "no numeric X-Curse-Project-ID in the TOC"
label="v$(toc_field Version)"
target=${GAME_VERSION:-$(interface_to_version "$(toc_field Interface)")}

if [ -n "$dry" ] && [ -z "${CF_VERSIONS_FILE:-}" ] && [ -z "${CF_API_TOKEN:-}" ]; then
    # The rehearsal runs without the token (ruleset plan 2026-10-24-release-environment):
    # the version list needs it, so the version comes from the TOC and the ID stays 0
    chosen=$target
    id=0
    echo "CurseForge: no token in a dry run - version $chosen from the TOC, the live list not checked"
else
    if [ -n "${CF_VERSIONS_FILE:-}" ]; then
        versions=$(cat "$CF_VERSIONS_FILE")
    else
        [ -n "${CF_API_TOKEN:-}" ] || fail "CF_API_TOKEN is not set"
        # The version list needs the token, so this also proves CurseForge takes it
        versions=$(curl -sS -f -H "x-api-token: $CF_API_TOKEN" "$api/game/wow/versions") \
            || fail "CurseForge refused the version list - is CF_API_TOKEN valid?"
    fi
    chosen=$(jq -r --argjson t "$forever_type" '.[] | select(.gameVersionTypeID == $t) | .name' <<< "$versions" \
        | resolve_game_version "$target")
    id=$(jq -r --argjson t "$forever_type" --arg v "$chosen" \
        '[.[] | select(.gameVersionTypeID == $t and .name == $v) | .id][0]' <<< "$versions")
fi

payload=$(jq -n --arg label "$label" --argjson id "$id" --rawfile changelog "$notes" \
    '{displayName: $label, gameVersions: [$id], releaseType: "release",
      changelog: $changelog, changelogType: "markdown"}')

echo "CurseForge: project $project, $(basename "$zip") as $label, WoW Forever $chosen (id $id)"
if [ -n "$dry" ]; then
    echo "dry run - nothing uploaded"
    exit 0
fi

# No retry: a timeout after an accepted upload would post the file twice.
result=$(mktemp)
code=$(printf '%s' "$payload" | curl -sS -o "$result" -w '%{http_code}' \
    -H "x-api-token: $CF_API_TOKEN" -F "metadata=<-" -F "file=@$zip" \
    "$api/projects/$project/upload-file") || fail "the upload did not complete"
[ "$code" = 200 ] || { cat "$result" >&2; fail "CurseForge refused the upload (HTTP $code)"; }
echo "uploaded to CurseForge"
