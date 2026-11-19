#!/usr/bin/env bash
# The interface font: Inter, for GTK and Qt/KDE apps. Arch and Ubuntu.
#
#   bootstrap/install-font.sh          install it and make every app use it
#   bootstrap/install-font.sh check    report what's set, change nothing
#
# Inter is downloaded from a pinned, checksummed release into
# ~/.local/share/fonts, so both laptops get the same version and no sudo is
# needed. The rendering settings and the "sans-serif means Inter" rule are in
# the fontconfig stow package (stow -t ~ fontconfig). The bar keeps its own
# font (Theme.qml). Safe to re-run.
set -uo pipefail

VERSION=4.1
SHA256=9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e
URL=https://github.com/rsms/inter/releases/download/v$VERSION/Inter-$VERSION.zip
FAMILY=Inter
SIZE=10.5

repo=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
dest=$HOME/.local/share/fonts/Inter

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

# Qt's font string: family, point size, then weight 400 (or 600) and defaults.
qtfont() { printf '%s,%s,-1,5,%s,0,0,0,0,0,0,0,0,0,0,1' "$FAMILY" "$1" "${2:-400}"; }

check() {
  say "Interface font ($FAMILY $SIZE):"
  if fc-list "$FAMILY" family | grep -qx "$FAMILY"; then row ok "$FAMILY installed"
  else row missing "$FAMILY not installed"; fi
  if [[ $(readlink -f ~/.config/fontconfig/fonts.conf) == "$repo/fontconfig/.config/fontconfig/fonts.conf" ]]; then
    row ok "fontconfig linked (sans-serif is $(fc-match -f '%{family}' sans-serif))"
  else row no "fontconfig not linked: cd $repo && stow -t ~ fontconfig"; fi
  command -v gsettings >/dev/null && row gtk "$(gsettings get org.gnome.desktop.interface font-name)"
  [[ -e ~/.config/kdeglobals ]] && row qt "$(sed -n '/^\[General\]/,/^\[/s/^font=//p' ~/.config/kdeglobals)"
}

install_font() {
  if [[ $(cat "$dest/.version" 2>/dev/null) == "$VERSION" ]]; then
    say "$FAMILY $VERSION already installed."
    return 0
  fi
  say "Downloading $FAMILY $VERSION..."
  local tmp
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/inter.zip" "$URL" || { echo "Download failed: $URL" >&2; return 1; }
  echo "$SHA256  $tmp/inter.zip" | sha256sum -c --quiet - \
    || { echo "Checksum mismatch, not installing." >&2; return 1; }
  # The static files: their family is plain "Inter" (the variable ones call
  # themselves "Inter Variable", which apps don't all match).
  mkdir -p "$dest"
  unzip -qjo "$tmp/inter.zip" 'extras/ttf/Inter-*.ttf' -d "$dest" || return 1
  echo "$VERSION" >"$dest/.version"
  fc-cache -f "$dest" >/dev/null
}

apply() {
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface font-name "$FAMILY $SIZE"
  fi
  local f
  for f in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
    [[ -e $f ]] || continue
    if grep -q '^gtk-font-name=' "$f"; then sed -i "s|^gtk-font-name=.*|gtk-font-name=$FAMILY $SIZE|" "$f"
    else sed -i "/^\[Settings\]/a gtk-font-name=$FAMILY $SIZE" "$f"; fi
  done
  local kw
  kw=$(command -v kwriteconfig6 || command -v kwriteconfig5)
  if [[ -n $kw ]]; then
    "$kw" --file kdeglobals --group General --key font "$(qtfont "$SIZE")"
    "$kw" --file kdeglobals --group General --key menuFont "$(qtfont "$SIZE")"
    "$kw" --file kdeglobals --group General --key toolBarFont "$(qtfont 10)"
    "$kw" --file kdeglobals --group General --key smallestReadableFont "$(qtfont 9)"
    "$kw" --file kdeglobals --group WM --key activeFont "$(qtfont "$SIZE" 600)"
  fi
}

case ${1:-} in
  check) check ;;
  "")
    install_font || exit 1
    apply
    echo
    check
    echo
    echo "Apps that were already open keep the old font until they restart."
    ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
