#!/bin/bash
# The stylesheet half of --uninstall, which is the only path here that can
# destroy user data.
#
# Two markers describe what was on disk before the first managed install:
# $d.pre-norvi (there was a stylesheet, here it is) and $d.norvi-absent-before
# (there was nothing). Exactly one exists while an install is managed and
# neither exists afterwards, so "should I delete this file?" never has to be
# answered by comparing contents. Getting it wrong deletes somebody's gtk.css.
#
#   ./test-uninstall-restore.sh     (exits non-zero on the first bad case)
set -uo pipefail

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

# Byte-identical to the uninstall branch in install-desktop.sh.
uninstall_one() {
  local d="$1"
  if [ -f "$d.pre-norvi" ]; then
    mv -f "$d.pre-norvi" "$d"
    rm -f "$d.norvi-absent-before"
  elif [ -f "$d.norvi-absent-before" ]; then
    rm -f "$d" "$d.norvi-absent-before"
  fi
}

check() {
  if [ "$2" = "$3" ]; then echo "ok   - $1"
  else echo "FAIL - $1"; echo "         want: $2"; echo "         got:  $3"; fail=1; fi
}
state() { [ -f "$1" ] && cat "$1" || echo "<absent>"; }

d="$TMP/gtk.css"

# The user had a stylesheet; we backed it up and installed ours.
printf 'USER\n' > "$d.pre-norvi"; printf 'NORVI\n' > "$d"
uninstall_one "$d"
check "restores the user's stylesheet" "USER" "$(state "$d")"

# ...and doing it again must not touch what was just restored.
uninstall_one "$d"
check "a second uninstall leaves the restored file alone" "USER" "$(state "$d")"

# The user had nothing; the sentinel says so.
rm -f "$d" "$d.pre-norvi"; printf 'NORVI\n' > "$d"; : > "$d.norvi-absent-before"
uninstall_one "$d"
check "removes our stylesheet when there was nothing before it" "<absent>" "$(state "$d")"

# ...and a retry finds no markers and does nothing, even if a file reappeared.
printf 'SOMETHING NEW\n' > "$d"
uninstall_one "$d"
check "a retry does not delete an unmanaged file" "SOMETHING NEW" "$(state "$d")"

# Never installed here at all: no markers, so hands off.
rm -f "$d".*; printf 'UNRELATED\n' > "$d"
uninstall_one "$d"
check "an unmanaged stylesheet is never touched" "UNRELATED" "$(state "$d")"

exit "$fail"
