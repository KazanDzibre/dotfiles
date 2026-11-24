#!/usr/bin/env bash
# The shell's icon font: Material Symbols Rounded (the bar, island and cards).
# Arch and Ubuntu.
#
#   bootstrap/install-icon-font.sh          install it
#   bootstrap/install-icon-font.sh check    report what's installed, change nothing
#
# Downloaded from a pinned commit of google/material-design-icons and checked
# against its checksum into ~/.local/share/fonts, so both laptops get the same
# glyphs (quickshell/.config/quickshell/Icons.qml addresses them by codepoint)
# and no sudo is needed. It is a variable font: Quickshell fills an icon in
# when its toggle is on. Safe to re-run.
set -uo pipefail

COMMIT=10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7
SHA256=7e74e36533ccee12c2b81e75bfcf3ccf123d3bb7e7e46d65d94445f23db0c97c
URL="https://raw.githubusercontent.com/google/material-design-icons/$COMMIT/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
FAMILY="Material Symbols Rounded"

dest=$HOME/.local/share/fonts/MaterialSymbols
file=$dest/MaterialSymbolsRounded.ttf

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

check() {
  say "Icon font ($FAMILY):"
  if fc-list "$FAMILY" family | grep -qx "$FAMILY"; then row ok "installed (${COMMIT:0:7})"
  else row missing "not installed: bootstrap/install-icon-font.sh"; fi
}

install_font() {
  if [[ $(cat "$dest/.version" 2>/dev/null) == "$COMMIT" && -e $file ]]; then
    say "$FAMILY ${COMMIT:0:7} already installed."
    return 0
  fi
  say "Downloading $FAMILY..."
  local tmp
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/font.ttf" "$URL" || { echo "Download failed: $URL" >&2; return 1; }
  echo "$SHA256  $tmp/font.ttf" | sha256sum -c --quiet - \
    || { echo "Checksum mismatch, not installing." >&2; return 1; }
  mkdir -p "$dest"
  mv -f "$tmp/font.ttf" "$file"
  echo "$COMMIT" >"$dest/.version"
  fc-cache -f "$dest" >/dev/null
}

case ${1:-} in
  check) check ;;
  "")
    install_font || exit 1
    echo
    check
    echo
    echo "Restart Quickshell to pick it up: qs kill, then start quickshell again."
    ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
