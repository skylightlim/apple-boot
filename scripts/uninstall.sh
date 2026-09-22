#!/usr/bin/env bash
# Remove the "apple" Plymouth theme and switch back to another one.
set -euo pipefail

THEME_NAME=apple
DEST="/usr/share/plymouth/themes/$THEME_NAME"
THEMES_DIR=/usr/share/plymouth/themes
FALLBACK=""

usage() {
  cat <<'USAGE'
Usage: sudo ./scripts/uninstall.sh [--theme NAME]

  --theme NAME   Theme to switch back to. Defaults to the first of
                 omarchy, bgrt, spinner, text that is installed.
USAGE
}

while (( $# )); do
  case "$1" in
    --theme) FALLBACK="${2:?--theme needs a name}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "error: run this with sudo" >&2; exit 1; }

if [[ -z $FALLBACK ]]; then
  for candidate in omarchy bgrt spinner text; do
    if [[ -d "$THEMES_DIR/$candidate" ]]; then FALLBACK=$candidate; break; fi
  done
fi
[[ -n $FALLBACK ]] || { echo "error: no fallback theme found; pass --theme" >&2; exit 1; }
[[ -d "$THEMES_DIR/$FALLBACK" ]] || { echo "error: no such theme: $FALLBACK" >&2; exit 1; }

echo "==> Switching back to: $FALLBACK"
plymouth-set-default-theme "$FALLBACK"

echo "==> Removing $DEST"
rm -rf "$DEST"

echo "==> Rebuilding the boot image"
if command -v limine-mkinitcpio >/dev/null; then limine-mkinitcpio
elif command -v mkinitcpio >/dev/null; then mkinitcpio -P
elif command -v dracut >/dev/null; then dracut --force --regenerate-all
else echo "warning: rebuild your initramfs manually" >&2; exit 1
fi

echo
echo "Done. Default theme is now: $(plymouth-set-default-theme)"
