#!/bin/bash
# check_gtk_css.py must fail when either stylesheet has a broken rule. A
# checker that only ever passes is how a stylesheet ends up styling nothing:
# an earlier draft skipped GTK 4 after loading GTK 3 in the same process, and
# passed a deliberately broken GTK 4 rule.
#
#   ./test-gtk-css-check.sh     (needs python3-gi, gir1.2-gtk-3.0, gir1.2-gtk-4.0)
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

# The checker reads the stylesheets beside it, so each case runs a copy.
case_run() {  # <name> <file to break> <sed expression> <want exit>
  rm -rf "$TMP/desktop"; cp -r "$HERE" "$TMP/desktop"
  [ -n "$2" ] && sed -i "$3" "$TMP/desktop/$2"
  python3 "$TMP/desktop/check_gtk_css.py" >"$TMP/out" 2>&1
  local got=$?
  if [ "$got" = "$4" ] && { [ -z "$2" ] || grep -q "ERROR desktop/$2:" "$TMP/out"; }; then
    echo "ok   - $1"
  else
    echo "FAIL - $1 (exit $got, want $4)"; sed 's/^/         /' "$TMP/out"; fail=1
  fi
}

case_run "both stylesheets parse clean" "" "" 0
case_run "a bad unit in gtk4.css fails" gtk4.css '0,/border-radius: 20px;/s//border-radius: 20pz;/' 1
case_run "a bad property in gtk3.css fails" gtk3.css '0,/background-color:/s//backgrond-color:/' 1

exit $fail
