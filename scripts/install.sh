#!/usr/bin/env bash
# Install the "apple" Plymouth theme.
#
# It is installed as its own theme directory rather than by overwriting an
# existing one, so a distro package upgrade (Omarchy's omarchy-settings, for
# example) can never clobber it.
set -euo pipefail

THEME_NAME=apple
DEST="/usr/share/plymouth/themes/$THEME_NAME"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/theme"

LOGO=""
LOGO_MAX=256
REBUILD=1

usage() {
  cat <<'USAGE'
Usage: sudo ./scripts/install.sh [options]

Options:
  --logo PATH       Use your own logo instead of the bundled one. Any PNG with
                    transparency works; it is converted to RGBA and shrunk to
                    fit --logo-size. Requires ImageMagick.
  --logo-size N     Max logo edge in pixels (default: 256). Plymouth draws the
                    logo at its native size, so this IS its on-screen size.
  --no-rebuild      Install and select the theme, but skip the initramfs
                    rebuild. The theme will not appear until you rebuild.
  -h, --help        Show this help.
USAGE
}

while (( $# )); do
  case "$1" in
    --logo)      LOGO="${2:?--logo needs a path}"; shift 2 ;;
    --logo-size) LOGO_MAX="${2:?--logo-size needs a number}"; shift 2 ;;
    --no-rebuild) REBUILD=0; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "error: run this with sudo" >&2; exit 1; }
[[ -d $SRC ]] || { echo "error: theme source not found at $SRC" >&2; exit 1; }
command -v plymouth-set-default-theme >/dev/null \
  || { echo "error: plymouth is not installed" >&2; exit 1; }

echo "==> Installing theme to $DEST"
install -d -m 755 "$DEST"
install -m 644 "$SRC"/apple.plymouth "$SRC"/apple.script "$SRC"/*.png "$DEST"/

if [[ -n $LOGO ]]; then
  [[ -f $LOGO ]] || { echo "error: no such file: $LOGO" >&2; exit 1; }
  command -v magick >/dev/null || command -v convert >/dev/null \
    || { echo "error: --logo needs ImageMagick" >&2; exit 1; }
  IM=$(command -v magick || command -v convert)
  echo "==> Using custom logo: $LOGO (max ${LOGO_MAX}px)"
  # '>' only shrinks, so a small logo keeps its size instead of being upscaled
  # into a blur. PNG32 forces real RGBA; ImageMagick otherwise demotes a
  # single-colour logo to grayscale+alpha.
  "$IM" "$LOGO" -resize "${LOGO_MAX}x${LOGO_MAX}>" \
    -colorspace sRGB -type TrueColorAlpha "PNG32:$DEST/logo.png"
fi

echo "==> Selecting $THEME_NAME as the default theme"
plymouth-set-default-theme "$THEME_NAME"

if (( ! REBUILD )); then
  echo
  echo "Theme installed and selected. Skipped the rebuild as asked --"
  echo "it will not show at boot until you regenerate your initramfs."
  exit 0
fi

echo "==> Rebuilding the boot image"
if command -v limine-mkinitcpio >/dev/null; then
  # Omarchy and other Limine setups boot a UKI. Plain 'mkinitcpio -P' rebuilds
  # the initramfs but leaves the UKI that actually boots untouched, so the
  # change silently does nothing.
  echo "    (Limine/UKI detected -- using limine-mkinitcpio)"
  limine-mkinitcpio
elif command -v mkinitcpio >/dev/null; then
  echo "    (mkinitcpio detected)"
  mkinitcpio -P
elif command -v dracut >/dev/null; then
  echo "    (dracut detected)"
  dracut --force --regenerate-all
else
  echo "warning: no known initramfs tool found. Rebuild it yourself," >&2
  echo "         otherwise the theme will not appear at boot." >&2
  exit 1
fi

echo
echo "Done. Default theme is now: $(plymouth-set-default-theme)"
echo "Reboot to see it. To undo: sudo ./scripts/uninstall.sh"
