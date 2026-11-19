#!/usr/bin/env bash
# Icons: Papirus Dark, with folders in the wallpaper's colour. Arch and Ubuntu.
#
#   bootstrap/install-icons.sh          install it and make every app use it
#   bootstrap/install-icons.sh check    report what's set, change nothing
#
# Papirus is downloaded from a pinned, checksummed release into
# ~/.local/share/icons, so both laptops get the same version and no sudo is
# needed. Next to it this makes Papirus-Dark-Wal, a small theme that inherits
# everything from Papirus-Dark and holds only the folder icons; theme-sync
# (wal/.local/bin) points those at the folder colour nearest the wallpaper's
# accent on every wallpaper change. Papirus-Dark-Wal is the theme apps use.
# Safe to re-run.
set -uo pipefail

VERSION=20260801
SHA256=646f622e9e7e9e65eef9d0ab58999d4920ddb33d98e6a75232627cfe3bd508f9
URL=https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/refs/tags/$VERSION.tar.gz
THEME=Papirus-Dark-Wal

repo=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
icons=$HOME/.local/share/icons
overlay=$icons/$THEME

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

check() {
  say "Icons ($THEME):"
  if [[ -e $icons/Papirus-Dark/index.theme ]]; then
    row ok "Papirus $(cat "$icons/Papirus/.version" 2>/dev/null || echo '?') in $icons"
  else row missing "Papirus not installed"; fi
  if [[ -e $overlay/index.theme ]]; then
    row ok "$THEME, folders: $(cat "$overlay/.colour" 2>/dev/null || echo 'not coloured yet')"
  else row missing "$THEME not made"; fi
  command -v gsettings >/dev/null && row gtk "$(gsettings get org.gnome.desktop.interface icon-theme)"
  local f
  for f in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
    [[ -e $f ]] && row ini "$f: $(grep -h '^gtk-icon-theme-name=' "$f" | cut -d= -f2)"
  done
  [[ -e ~/.config/kdeglobals ]] && row qt "$(sed -n '/^\[Icons\]/,/^\[/s/^Theme=//p' ~/.config/kdeglobals)"
}

install_papirus() {
  if [[ $(cat "$icons/Papirus/.version" 2>/dev/null) == "$VERSION" && -e $icons/Papirus-Dark/index.theme ]]; then
    say "Papirus $VERSION already installed."
    return 0
  fi
  say "Downloading Papirus $VERSION..."
  local tmp
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/papirus.tar.gz" "$URL" || { echo "Download failed: $URL" >&2; return 1; }
  echo "$SHA256  $tmp/papirus.tar.gz" | sha256sum -c --quiet - \
    || { echo "Checksum mismatch, not installing." >&2; return 1; }
  tar -xzf "$tmp/papirus.tar.gz" -C "$tmp" \
    "papirus-icon-theme-$VERSION/Papirus" "papirus-icon-theme-$VERSION/Papirus-Dark" || return 1
  mkdir -p "$icons"
  rm -rf "$icons/Papirus" "$icons/Papirus-Dark"
  mv "$tmp/papirus-icon-theme-$VERSION/Papirus" "$tmp/papirus-icon-theme-$VERSION/Papirus-Dark" "$icons/"
  echo "$VERSION" >"$icons/Papirus/.version"
  if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -qf "$icons/Papirus" 2>/dev/null
    gtk-update-icon-cache -qf "$icons/Papirus-Dark" 2>/dev/null
  fi
  rm -f "$overlay/.colour" # the folder links point into the old copy
}

make_overlay() {
  # Only the places directories, with Papirus-Dark's sizes and scales.
  mkdir -p "$overlay"
  local dirs scaled
  dirs=$(grep -m1 '^Directories=' "$icons/Papirus-Dark/index.theme" | tr ',' '\n' | grep '/places$' | grep -v @ | paste -sd,)
  scaled=$(grep -m1 '^ScaledDirectories=' "$icons/Papirus-Dark/index.theme" | tr ',' '\n' | grep '/places$' | paste -sd,)
  {
    printf '[Icon Theme]\nName=%s\nComment=Papirus Dark with folders in the wallpaper colour (theme-sync)\n' "$THEME"
    printf 'Inherits=Papirus-Dark,breeze-dark,hicolor\nDirectories=%s\nScaledDirectories=%s\n' "$dirs" "$scaled"
    local d
    for d in ${dirs//,/ } ${scaled//,/ }; do
      printf '\n'
      sed -n "/^\[${d//\//\\/}\]/,/^$/p" "$icons/Papirus-Dark/index.theme" | sed '/^$/d'
    done
  } >"$overlay/index.theme"
}

apply() {
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface icon-theme "$THEME"
  fi
  local f
  for f in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
    [[ -e $f ]] || continue
    if grep -q '^gtk-icon-theme-name=' "$f"; then sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$THEME|" "$f"
    else sed -i "/^\[Settings\]/a gtk-icon-theme-name=$THEME" "$f"; fi
  done
  local kw
  kw=$(command -v kwriteconfig6 || command -v kwriteconfig5)
  [[ -n $kw ]] && "$kw" --file kdeglobals --group Icons --key Theme "$THEME"

  # The folder colour for the current wallpaper.
  local sync
  sync=$(command -v theme-sync || echo "$repo/wal/.local/bin/theme-sync")
  if [[ -e $HOME/.cache/wal/colors.json ]]; then
    "$sync" icons >/dev/null || echo "theme-sync icons failed; folders stay blue until the next wallpaper change." >&2
  else
    echo "No wallpaper palette yet: folders stay blue until the first wallpaper change." >&2
  fi
}

case ${1:-} in
  check) check ;;
  "")
    install_papirus || exit 1
    make_overlay
    apply
    echo
    check
    echo
    echo "Apps that were already open keep their icons until they restart."
    ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
