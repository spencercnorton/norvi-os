#!/bin/bash
# Runs the real install-desktop.sh end to end against a scratch HOME, with stub
# gsettings and gnome-extensions. The other two tests check copies of its
# functions in a shell without `set -e`, and so could not see the script's own
# `set -e` turn a second --uninstall into a silent exit 1.
#
#   ./test-install-desktop.sh     (exits non-zero on the first bad case)
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0

mkdir -p "$TMP/bin"
cat > "$TMP/bin/gsettings" <<'STUB'
#!/bin/sh
# gsettings get|set <schema> <key> [value]: one file per key, absent = Blur my Shell's default
f="$STUB_DCONF/$3"
case "$1" in
  get) if [ -f "$f" ]; then cat "$f"; else case "$3" in
         blur|enable-all) echo false ;; dynamic-opacity) echo true ;; opacity) echo 215 ;;
         blacklist) echo "['Plank', 'com.desktop.ding', 'Conky']" ;; esac; fi ;;
  set) printf '%s\n' "$4" > "$f" ;;
esac
STUB
cat > "$TMP/bin/gnome-extensions" <<'STUB'
#!/bin/sh
printf 'blur-my-shell@aunetx\n  Enabled: Yes\n  State: %s\n' "$STUB_BMS_STATE"
STUB
chmod +x "$TMP/bin/gsettings" "$TMP/bin/gnome-extensions"
export PATH="$TMP/bin:$PATH"

fresh() {  # a new user: Blur my Shell installed, dconf at its defaults
  rm -rf "${TMP:?}/home" "${TMP:?}/dconf"; mkdir -p "$TMP/dconf"
  export HOME="$TMP/home" STUB_DCONF="$TMP/dconf" STUB_BMS_STATE=ACTIVE
  unset XDG_CONFIG_HOME XDG_STATE_HOME
  mkdir -p "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
}
run() { "$HERE/install-desktop.sh" "$@" >"$TMP/out" 2>&1; echo $?; }
check() {
  if [ "$2" = "$3" ]; then echo "ok   - $1"
  else echo "FAIL - $1"; echo "         want: $2"; echo "         got:  $3"; sed 's/^/         | /' "$TMP/out"; fail=1; fi
}
key() { gsettings get schema "$1"; }

fresh
mkdir -p "$HOME/.config/gtk-3.0"; chmod 775 "$HOME/.config/gtk-3.0"
echo '/* mine */' > "$HOME/.config/gtk-3.0/gtk.css"
check "install exits 0" 0 "$(run)"
check "install turns application blur on" true "$(key blur)"
check "install keeps the user's gtk-3.0 directory mode" 775 "$(stat -c %a "$HOME/.config/gtk-3.0")"
check "the absent-before marker is not executable" no "$([ -x "$HOME/.config/gtk-4.0/gtk.css.norvi-absent-before" ] && echo yes || echo no)"
check "uninstall exits 0" 0 "$(run --uninstall)"
check "uninstall restores the user's stylesheet" '/* mine */' "$(cat "$HOME/.config/gtk-3.0/gtk.css")"
check "uninstall removes the stylesheet it added" no "$([ -e "$HOME/.config/gtk-4.0/gtk.css" ] && echo yes || echo no)"
check "uninstall restores application blur" false "$(key blur)"
check "uninstall restores the blacklist" "['Plank', 'com.desktop.ding', 'Conky']" "$(key blacklist)"
check "a second uninstall exits 0" 0 "$(run --uninstall)"
check "and says it is done" yes "$(grep -q '^DONE' "$TMP/out" && echo yes || echo no)"

fresh
check "--stylesheet-only exits 0" 0 "$(run --stylesheet-only)"
check "and leaves the blur alone" false "$(key blur)"
check "uninstall after --stylesheet-only exits 0" 0 "$(run --uninstall)"

fresh; STUB_BMS_STATE=INITIALIZED
check "refuses while blur-my-shell is installed but not running" 1 "$(run)"
check "and writes nothing" no "$([ -e "$HOME/.config/gtk-4.0" ] && echo yes || echo no)"
check "--stylesheet-only does not need it running" 0 "$(run --stylesheet-only)"

fresh; rm -rf "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx"
check "refuses when blur-my-shell is not installed" 1 "$(run)"

exit $fail
