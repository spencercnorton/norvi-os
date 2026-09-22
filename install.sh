#!/usr/bin/env bash
# norvi-os — NorviTech branding for Ubuntu (boot splash, GDM login/lock logo, About logo).
# Idempotent; safe to re-run. Tested on Ubuntu 26.04 LTS / GNOME 50.
#
# Upgrade-safety design:
#   - Plymouth: own theme dir + update-alternatives (priority 200 > Ubuntu's 110).
#     No Ubuntu-owned file is modified; `update-alternatives --remove` reverts.
#   - GDM: edits /etc/gdm3/greeter.dconf-defaults, a ucf-managed conffile whose
#     local changes survive gdm3 upgrades. It is symlinked into the dir that
#     /usr/share/gdm/generate-config (gdm3.service ExecStartPre) compiles at every
#     start. The edit is staged + validated (dconf compile) + atomically moved,
#     so a malformed result can never reach the live greeter and block login.
#   - About logo: dpkg-divert on the two base-files pixmaps that gnome-control-center
#     loads by hardcoded path (GtkPicture — no icon-theme lookup in GTK4). Diversions
#     survive base-files upgrades and revert cleanly.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo ./install.sh" >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE=/usr/local/share/norvitech
THEME_DIR=/usr/share/plymouth/themes/norvitech
SPINNER=/usr/share/plymouth/themes/spinner
GREETER=/etc/gdm3/greeter.dconf-defaults
GDM_LOGO="$SHARE/norvitech-gdm-logo.svg"
DIVERT_SUFFIX=.stock-norvi

echo "== assets -> $SHARE"
install -d "$SHARE"
install -m644 "$SRC"/assets/norvitech-logo-*.svg "$SRC"/assets/norvitech-logo-*-380.png \
              "$SRC"/gdm/norvitech-gdm-logo.svg "$SHARE/"

echo "== plymouth theme -> $THEME_DIR"
install -d "$THEME_DIR"
# Real copies, not symlinks: the plymouth initramfs hook `cp -a`s only the theme
# dir itself, so symlinks into ../spinner would dangle inside the initramfs.
find "$SPINNER" -maxdepth 1 -type f ! -name 'spinner.plymouth' -exec cp -t "$THEME_DIR" {} +
install -m644 "$SRC/plymouth/watermark.png" "$THEME_DIR/watermark.png"
install -m644 "$SRC/plymouth/norvitech.plymouth" "$THEME_DIR/norvitech.plymouth"

update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
  default.plymouth "$THEME_DIR/norvitech.plymouth" 200
update-alternatives --auto default.plymouth

echo "== rebuilding initramfs for all installed kernels (~1 min)"
# -k all: the plymouth hook reads the alternatives link at every future initramfs
# build, but existing kernels' initrds must be rebuilt now to pick up the theme.
update-initramfs -u -k all
NEWEST_INITRD="$(ls -1v /boot/initrd.img-* | tail -1)"
# No -q: grep -q closes the pipe early -> SIGPIPE/pipefail marks a healthy run failed.
if lsinitramfs "$NEWEST_INITRD" | grep -F "norvitech/watermark.png" >/dev/null; then
  echo "OK: NorviTech watermark baked into $NEWEST_INITRD"
else
  echo "WARNING: watermark not found in $NEWEST_INITRD — boot splash may still be stock" >&2
fi

echo "== GDM greeter logo (staged + validated + atomic)"
set_greeter_logo() {
  local want="logo='$GDM_LOGO'" tmp
  tmp="$(mktemp "$GREETER.XXXXXX")"
  cp "$GREETER" "$tmp"
  if grep -qxF "$want" "$tmp"; then
    :
  elif grep -qE '^#? ?logo=' "$tmp"; then
    sed -i -E "s|^#? ?logo=.*|$want|" "$tmp"
  else
    printf '\n# norvi-os branding\n[org/gnome/login-screen]\n%s\n' "$want" >> "$tmp"
  fi
  # Validate the candidate compiles before it can reach the live greeter.
  local vd vout; vd="$(mktemp -d)"; vout="$(mktemp -u)"
  cp "$tmp" "$vd/candidate"
  if ! dconf compile "$vout" "$vd" 2>/dev/null; then
    rm -rf "$tmp" "$vd" "$vout"
    echo "ERROR: edited greeter would not compile — aborting, greeter left unchanged" >&2
    exit 1
  fi
  rm -rf "$vd" "$vout"
  chmod 644 "$tmp"
  mv -f "$tmp" "$GREETER"   # same dir -> atomic rename
}
set_greeter_logo
/usr/share/gdm/generate-config
if strings /var/lib/gdm3/greeter-dconf-defaults | grep -q norvitech-gdm-logo; then
  echo "OK: greeter dconf db carries the NorviTech logo"
else
  echo "WARNING: greeter db missing the logo key" >&2
fi

echo "== About-panel logo (dpkg-divert base-files pixmaps)"
# gnome-control-center loads these two paths directly as a GtkPicture; there is no
# icon-name/hicolor fallback in GTK4. Divert the stock files aside and drop ours in.
# ubuntu-logo-text.svg = light UI mode -> dark artwork; -dark.svg = dark UI -> light.
divert_logo() {
  local stock="$1" ours="$2" backup="${1}${DIVERT_SUFFIX}"
  # --no-rename (not --rename): base-files is Essential; letting dpkg move its
  # files is flagged dangerous. dpkg only redirects the package's *future* writes
  # to $backup and never touches our file, so we keep our own stock backup.
  if ! dpkg-divert --list "$stock" | grep -qF "$DIVERT_SUFFIX"; then
    dpkg-divert --add --no-rename --divert "$backup" "$stock" >/dev/null
  fi
  [ -e "$backup" ] || cp -a "$stock" "$backup"   # guard: never clobber the stock backup on re-run
  install -m644 "$ours" "$stock"
}
divert_logo /usr/share/pixmaps/ubuntu-logo-text.svg      "$SRC/assets/norvitech-logo-dark.svg"
divert_logo /usr/share/pixmaps/ubuntu-logo-text-dark.svg "$SRC/assets/norvitech-logo-light.svg"

date "+norvi-os installed %F %T" > "$SHARE/VERSION"
echo
echo "DONE. Boot splash + login screen apply on next boot (GDM logo also after logout)."
echo "Settings > About shows the new logo when reopened."
