#!/usr/bin/env bash
# norvi-os — remove NorviTech branding, restore stock Ubuntu boot/login/About.
# Idempotent; safe on a box where install.sh never ran.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./uninstall.sh" >&2; exit 1; }

THEME_DIR=/usr/share/plymouth/themes/norvitech
GREETER=/etc/gdm3/greeter.dconf-defaults
DIVERT_SUFFIX=.stock-norvi

echo "== plymouth"
update-alternatives --remove default.plymouth "$THEME_DIR/norvitech.plymouth" 2>/dev/null || true
rm -rf "$THEME_DIR"
update-initramfs -u -k all

echo "== About-panel pixmaps (undo diversions)"
undivert_logo() {
  local stock="$1" backup="${1}${DIVERT_SUFFIX}"
  if dpkg-divert --list "$stock" | grep -qF "$DIVERT_SUFFIX"; then
    [ -e "$backup" ] && mv -f "$backup" "$stock"       # restore stock from our backup
    dpkg-divert --remove --no-rename "$stock" >/dev/null
  fi
}
undivert_logo /usr/share/pixmaps/ubuntu-logo-text.svg
undivert_logo /usr/share/pixmaps/ubuntu-logo-text-dark.svg

echo "== GDM greeter logo"
if [ -f "$GREETER" ]; then
  # restore the stock commented-out logo line, drop our appended marker block
  sed -i -E "s|^logo='/usr/local/share/norvitech/.*|#logo='/usr/share/images/vendor-logos/logo-text-version-64.png'|" "$GREETER"
  sed -i '/^# norvi-os branding$/d' "$GREETER"
  /usr/share/gdm/generate-config || true
fi

rm -rf /usr/local/share/norvitech
echo "DONE. Stock Ubuntu branding restored (visible from next boot)."
