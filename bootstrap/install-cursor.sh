#!/usr/bin/env bash
# The mouse cursor: Bibata Modern Classic, on Arch and Ubuntu alike.
#
#   bootstrap/install-cursor.sh          install it and make every app use it
#   bootstrap/install-cursor.sh check    report what's set, change nothing
#
# The theme is ~27 MB of images, so it isn't kept in the repo: this downloads
# a pinned release into ~/.local/share/icons and checks its checksum. Hyprland
# picks the theme and size up from hyprland.lua / hyprland.conf (the
# XCURSOR_* and HYPRCURSOR_* variables); this script sets the same thing for
# GTK, Qt/KDE and X apps, which each read it from somewhere else. Safe to
# re-run. Change THEME_SIZE here and in the Hyprland config together.
set -uo pipefail

THEME=Bibata-Modern-Classic
THEME_SIZE=20
VERSION=v2.0.7
SHA256=7d3495864e5bbef02f5e77de760b2905903b63c71495a78ef6306d19a3b556d8
URL=https://github.com/ful1e5/Bibata_Cursor/releases/download/$VERSION/$THEME.tar.xz

icons=$HOME/.local/share/icons

say() { printf '\033[1m%s\033[0m\n' "$*"; }
row() { printf '  %-8s %s\n' "$1" "$2"; }

check() {
  say "Cursor ($THEME, size $THEME_SIZE):"
  if [[ -e $icons/$THEME/cursors/left_ptr ]]; then row ok "theme installed in $icons"
  else row missing "theme not installed"; fi
  if grep -qs "Inherits=$THEME" "$icons/default/index.theme"; then row ok "default for X apps"
  else row no "not the default for X apps ($icons/default/index.theme)"; fi
  if command -v gsettings >/dev/null; then
    row gtk "$(gsettings get org.gnome.desktop.interface cursor-theme) size $(gsettings get org.gnome.desktop.interface cursor-size)"
  fi
  local f
  for f in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini; do
    [[ -e $f ]] && row ini "$f: $(grep -h '^gtk-cursor-theme-name=' "$f" | cut -d= -f2)"
  done
  [[ -e ~/.config/kcminputrc ]] && row qt "$(grep -h '^cursorTheme=' ~/.config/kcminputrc | cut -d= -f2)"
  if command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    row hypr "running session: XCURSOR_THEME=${XCURSOR_THEME:-unset} XCURSOR_SIZE=${XCURSOR_SIZE:-unset}"
  fi
}

install_theme() {
  if [[ -e $icons/$THEME/cursors/left_ptr ]]; then
    say "Theme already installed."
    return 0
  fi
  say "Downloading $THEME $VERSION..."
  local tmp
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/theme.tar.xz" "$URL" || { echo "Download failed: $URL" >&2; return 1; }
  echo "$SHA256  $tmp/theme.tar.xz" | sha256sum -c --quiet - \
    || { echo "Checksum mismatch, not installing." >&2; return 1; }
  mkdir -p "$icons"
  tar -xJf "$tmp/theme.tar.xz" -C "$icons" || return 1
}

# key=value in an ini file: replace the line if it's there, else add it under
# [Settings]. Only for the GTK files, which GTK and KDE's settings write too.
set_ini() {
  local file=$1 key=$2 value=$3
  [[ -e $file ]] || return 0
  if grep -q "^$key=" "$file"; then
    sed -i "s|^$key=.*|$key=$value|" "$file"
  else
    sed -i "/^\[Settings\]/a $key=$value" "$file"
  fi
}

apply() {
  # X and Xwayland apps, and anything else that asks for "default".
  mkdir -p "$icons/default"
  printf '[Icon Theme]\nInherits=%s\n' "$THEME" >"$icons/default/index.theme"

  # GTK 3/4 (and Flatpaks, through the portal).
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME"
    gsettings set org.gnome.desktop.interface cursor-size "$THEME_SIZE"
  fi
  set_ini ~/.config/gtk-3.0/settings.ini gtk-cursor-theme-name "$THEME"
  set_ini ~/.config/gtk-3.0/settings.ini gtk-cursor-theme-size "$THEME_SIZE"
  set_ini ~/.config/gtk-4.0/settings.ini gtk-cursor-theme-name "$THEME"
  set_ini ~/.config/gtk-4.0/settings.ini gtk-cursor-theme-size "$THEME_SIZE"

  # Qt and KDE apps (QT_QPA_PLATFORMTHEME=kde reads kcminputrc).
  local kw
  kw=$(command -v kwriteconfig6 || command -v kwriteconfig5)
  if [[ -n $kw ]]; then
    "$kw" --file kcminputrc --group Mouse --key cursorTheme "$THEME"
    "$kw" --file kcminputrc --group Mouse --key cursorSize "$THEME_SIZE"
  fi

  # The running Hyprland, so there's no need to log out to see it.
  if command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl setcursor "$THEME" "$THEME_SIZE" >/dev/null
  fi
}

case ${1:-} in
  check) check ;;
  "")
    install_theme || exit 1
    apply
    echo
    check
    echo
    echo "Apps that were already open keep the old cursor until they restart."
    ;;
  *) echo "usage: $0 [check]" >&2; exit 2 ;;
esac
