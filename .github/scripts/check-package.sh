#!/usr/bin/env bash
# Checks a packaged release before anything is published: the zip holds the
# addon folder alone and complete, and release.json makes WowUp offer it to a
# WoW Forever client. With a tag, the TOC version must be the tag's.
#
# Usage: check-package.sh <zip> <release.json> [<tag>]
set -euo pipefail

zip="$1"
meta="$2"
tag="${3:-}"
addon="SmartBlessingBar"

fail() { echo "PACKAGE CHECK FAILED: $*" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$zip" -d "$work"

top=$(ls -A "$work")
[ "$top" = "$addon" ] || fail "the zip's top level holds '$(echo $top)', expected $addon/ alone"
dir="$work/$addon"
toc="$dir/$addon.toc"
[ -f "$toc" ] || fail "no $addon.toc in $addon/"

# Bindings.xml is read by the client itself, the TOC does not list it (ruleset plan
# 2026-10-20-key-bindings)
for file in README.md LICENSE CHANGELOG.md Bindings.xml; do
    [ -f "$dir/$file" ] || fail "$file is missing"
done

# Every file the TOC loads
while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    [ -f "$dir/$line" ] || fail "the TOC lists $line, which is not in the zip"
done < "$toc"

# Nothing else ships: every file is one the TOC loads, the TOC itself, or one of the four
# above, and every folder holds one of them. A list of what must not ship would let a file
# added to the repository later through (ruleset plan 2026-10-24-review-code-fixes).
lists=$(mktemp -d)
trap 'rm -rf "$work" "$lists"' EXIT
{
    printf '%s\n' "$addon.toc" README.md LICENSE CHANGELOG.md Bindings.xml
    while IFS= read -r line; do
        line="${line%$'\r'}"
        case "$line" in ''|'#'*) continue ;; esac
        echo "${line//\\//}"
    done < "$toc"
} | sort -u > "$lists/files"
# every folder above a listed file: libs/X/X.lua allows libs/X and libs
awk -F/ '{ p = ""; for (i = 1; i < NF; i++) { p = p (i > 1 ? "/" : "") $i; print p } }' "$lists/files" | sort -u > "$lists/folders"
(cd "$dir" && find . -mindepth 1 ! -type d | sed 's|^\./||' | sort) > "$lists/shipped"
(cd "$dir" && find . -mindepth 1 -type d | sed 's|^\./||' | sort) > "$lists/shipped-folders"
extra=$(comm -23 "$lists/shipped" "$lists/files")
[ -z "$extra" ] || fail "not part of the addon, must not ship: $(echo $extra)"
extra=$(comm -23 "$lists/shipped-folders" "$lists/folders")
[ -z "$extra" ] || fail "a folder that is not part of the addon, must not ship: $(echo $extra)"

field() { grep -m1 -E "^## $1:" "$toc" | sed -E "s/^## $1:[[:space:]]*//" | tr -d '\r[:space:]'; }
interface=$(field Interface)
version=$(field Version)

jq -e --arg file "$(basename "$zip")" --argjson interface "$interface" '
    (.releases | length) == 1
    and .releases[0].filename == $file
    and .releases[0].nolib == false
    and (.releases[0].metadata | length) == 1
    and .releases[0].metadata[0].flavor == "forever"
    and .releases[0].metadata[0].interface == $interface' "$meta" > /dev/null \
    || fail "release.json does not name $(basename "$zip") under flavor forever, interface $interface"

if [ -n "$tag" ]; then
    [ "v$version" = "$tag" ] || fail "the TOC says $version, the tag is $tag"
fi

echo "package check passed: $(basename "$zip"), TOC version $version, interface $interface"
