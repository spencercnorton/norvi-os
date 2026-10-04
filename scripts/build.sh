#!/usr/bin/env bash
# Build the norvi-os metapackage from this tree. It installs no files of its
# own beyond its documentation; it is its dependencies. Reproducible under
# SOURCE_DATE_EPOCH.
#   scripts/build.sh [out-dir]      (default: dist/)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(realpath -m "${1:-$root/dist}")
pkg=norvi-os
version=$(dpkg-parsechangelog -l "$root/debian/changelog" -S Version)
stamp=${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct 2>/dev/null || date +%s)}
export SOURCE_DATE_EPOCH="$stamp"
mkdir -p "$out"

(cd "$root" && dpkg-buildpackage -us -uc -b)
mv "$root/../${pkg}_${version}_all.deb" "$out/"
rm -f "$root/../${pkg}_${version}"_*.buildinfo "$root/../${pkg}_${version}"_*.changes
test "$(dpkg-deb --field "$out/${pkg}_${version}_all.deb" Depends)" = norvi-archive-keyring
ls -l "$out"
