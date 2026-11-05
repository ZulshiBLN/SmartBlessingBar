#!/usr/bin/env bash
# Uploads a checked release zip to Wago, filed under WoW Forever. The endpoint
# and payload are the BigWigs packager's (upload_wago at the pinned commit);
# the packager uploads only a zip it builds in the same run, so the checks
# could not come before its upload.
#
# Usage: upload-wago.sh [--dry-run] <zip> <notes.md>
# The token comes from WAGO_API_TOKEN and is never printed.
# --dry-run resolves the game version and builds the payload, uploads nothing.
# Wago's version list is public, so a dry run needs no token.
# For the CI controls only, with --dry-run: WAGO_VERSIONS_FILE replaces the
# site's version list, GAME_VERSION the version the TOC asks for.
set -euo pipefail
. "$(dirname "$0")/lib-forever.sh"

dry=""
if [ "${1:-}" = --dry-run ]; then dry=1; shift; fi
zip="$1"
notes="$2"

api="https://addons.wago.io/api"

if [ -z "$dry" ] && [ -n "${WAGO_VERSIONS_FILE:-}${GAME_VERSION:-}" ]; then
    fail "WAGO_VERSIONS_FILE and GAME_VERSION are for dry runs only"
fi

project=$(toc_field X-Wago-ID)
[[ "$project" =~ ^[A-Za-z0-9]+$ ]] || fail "no X-Wago-ID in the TOC"
label="v$(toc_field Version)"
target=${GAME_VERSION:-$(interface_to_version "$(toc_field Interface)")}

# A real upload needs the token, checked before anything goes over the network; the
# rehearsal runs without it (ruleset plan 2026-10-24-release-environment)
[ -n "$dry" ] || [ -n "${WAGO_API_TOKEN:-}" ] || fail "WAGO_API_TOKEN is not set"
if [ -n "${WAGO_VERSIONS_FILE:-}" ]; then
    versions=$(cat "$WAGO_VERSIONS_FILE")
else
    versions=$(curl -sS -f "$api/data/game") || fail "Wago did not return its version list"
fi

chosen=$(jq -r '.patches.forever // [] | .[]' <<< "$versions" | resolve_game_version "$target")

payload=$(jq -n --arg label "$label" --arg v "$chosen" --rawfile changelog "$notes" \
    '{label: $label, supported_forever_patches: [$v], stability: "stable", changelog: $changelog}')

echo "Wago: project $project, $(basename "$zip") as $label, Forever $chosen"
if [ -n "$dry" ]; then
    echo "dry run - nothing uploaded"
    exit 0
fi

# No retry: a timeout after an accepted upload would post the file twice.
result=$(mktemp)
code=$(printf '%s' "$payload" | curl -sS -o "$result" -w '%{http_code}' \
    -H "authorization: Bearer $WAGO_API_TOKEN" -H "accept: application/json" \
    -F "metadata=<-" -F "file=@$zip" \
    "$api/projects/$project/version") || fail "the upload did not complete"
case "$code" in
    200|201) echo "uploaded to Wago" ;;
    *) cat "$result" >&2; fail "Wago refused the upload (HTTP $code)" ;;
esac
