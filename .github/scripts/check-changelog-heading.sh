#!/usr/bin/env bash
# A release needs its CHANGELOG entry dated: the heading of the TOC's version
# must read "## [x.y.z] - YYYY-MM-DD". The zip ships the CHANGELOG and a
# release cannot be withdrawn, so an undated or "Unreleased" heading is
# refused before anything is published (as SimpleConjureBar's 1.1.0 review,
# F-12).
#
# Usage: check-changelog-heading.sh <version> <CHANGELOG.md>
set -uo pipefail
version="$1"; changelog="$2"
heading=$(grep -m1 -F "## [$version]" "$changelog" | tr -d '\r')
if [ -z "$heading" ]; then
    echo "no CHANGELOG heading for $version"; exit 1
fi
if ! printf '%s\n' "$heading" | grep -qE "^## \[$version\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$"; then
    echo "the CHANGELOG heading of $version carries no release date: $heading"; exit 1
fi
echo "CHANGELOG heading of $version is dated"
