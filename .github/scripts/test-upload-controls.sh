#!/usr/bin/env bash
# Controls for the upload scripts that need no network and no jq: the version
# rule on fixed version lists, the interface mapping, and the token check.
# Each must be able to go red; CI runs this on every push.
#
# Usage: test-upload-controls.sh
set -uo pipefail
here=$(dirname "$0")
. "$here/lib-forever.sh"

failed=0
bad() { echo "CONTROL FAILED: $*" >&2; failed=1; }

# expect <name> <listed versions, one per line> <target> <expected> <warning: yes|no>
expect() {
    local name="$1" listed="$2" target="$3" want="$4" warn="$5" got err
    err=$(mktemp)
    got=$(resolve_game_version "$target" <<< "$listed" 2> "$err")
    [ "$got" = "$want" ] || bad "$name: got '$got', expected '$want'"
    if [ "$warn" = yes ]; then
        grep -q WARNING "$err" || bad "$name: no warning"
    else
        ! grep -q WARNING "$err" || bad "$name: an unexpected warning"
    fi
    rm -f "$err"
}

expect "exact"            $'1.50.0\n1.60.1' 1.60.1  1.60.1 no
expect "above all listed" $'1.50.0\n1.60.1' 1.99.9  1.60.1 yes
expect "below all listed" $'1.50.0\n1.60.1' 0.0.1   1.60.1 yes
expect "numeric order"    $'1.60.1\n1.99.0' 1.100.0 1.99.0 yes
# Only here do numeric and string comparison disagree: as strings 1.80.0 sorts
# below 1.9.0, and the case above comes out the same either way.
expect "numeric, not string" $'1.8.0\n1.80.0' 1.9.0 1.8.0 yes

if resolve_game_version 1.60.1 <<< "" > /dev/null 2>&1; then
    bad "no Forever version listed: resolved instead of failing"
fi

[ "$(interface_to_version 16001)" = 1.60.1 ] || bad "16001 is not 1.60.1"
[ "$(interface_to_version 110205)" = 11.2.5 ] || bad "110205 is not 11.2.5"

# The token check passes the real scripts and refuses one that prints a token
bash "$here/check-no-token-output.sh" "$here/upload-curseforge.sh" "$here/upload-wago.sh" > /dev/null \
    || bad "the token check refused the upload scripts"
leak=$(mktemp)
cp "$here/upload-curseforge.sh" "$leak"
echo 'echo "$CF_API_TOKEN"' >> "$leak"
if bash "$here/check-no-token-output.sh" "$leak" > /dev/null 2>&1; then
    bad "the token check accepted a script that prints CF_API_TOKEN"
fi
rm -f "$leak"


# The CHANGELOG heading check passes a dated heading and refuses an undated,
# an "Unreleased" and a missing one
log=$(mktemp)
printf '## [9.9.9] - 2026-10-22\n\n## [9.9.8]\n\n## [9.9.7] - Unreleased\n' > "$log"
bash "$here/check-changelog-heading.sh" 9.9.9 "$log" > /dev/null || bad "the heading check refused a dated heading"
for v in 9.9.8 9.9.7 9.9.6; do
    if bash "$here/check-changelog-heading.sh" "$v" "$log" > /dev/null 2>&1; then
        bad "the heading check accepted heading $v"
    fi
done
rm -f "$log"
[ "$failed" = 0 ] || exit 1
echo "upload controls passed"
