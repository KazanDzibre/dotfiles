#!/usr/bin/env bash
# Make Ptyxis match the rest of the desktop.
#
# Ptyxis keeps its settings in dconf, not in a file, so there is nothing here
# that stow could link -- which is why this package ships a script that writes
# the settings instead of a config to symlink. Run it once after installing;
# re-run it any time the settings get reset.
#
#   ptyxis-theme.sh            apply
#   ptyxis-theme.sh --show     print what is set now, change nothing
#
# The colours themselves are NOT set here. They come from the pywal palette
# written to ~/.local/share/org.gnome.Ptyxis/palettes/pywal.palette on every
# wallpaper change by waypaper/wallpaper_update.sh; this script only selects it.
# So the terminal follows the wallpaper exactly like the bar and rofi do.
#
# Note on when changes appear: Ptyxis applies font, padding and opacity to open
# windows immediately, but a window keeps the *palette* it started with. Open a
# new window after a wallpaper change to see new colours.

set -uo pipefail

SCHEMA="org.gnome.Ptyxis"
PROFILE_SCHEMA="org.gnome.Ptyxis.Profile"

# FantasqueSansM Nerd Font is what the Quickshell bar uses (Theme.fontFamily),
# so the terminal and the bar share one typeface. It must be the Nerd Font
# build: the plain Fantasque has none of the glyphs a prompt or the bar draws.
FONT="FantasqueSansM Nerd Font 12"
PALETTE="pywal"
OPACITY="0.92"

have() { command -v "$1" >/dev/null 2>&1; }

have gsettings || { echo "ptyxis-theme: gsettings not found" >&2; exit 1; }
gsettings list-schemas 2>/dev/null | grep -qx "$SCHEMA" \
    || { echo "ptyxis-theme: $SCHEMA schema not installed -- is ptyxis installed?" >&2; exit 1; }

# Every profile lives under its own uuid; the path form of gsettings is the only
# way to reach a relocatable schema like this one.
profile_path() {
    local uuid
    uuid="$(gsettings get "$SCHEMA" default-profile-uuid | tr -d "'")"
    [ -n "$uuid" ] || return 1
    printf '/org/gnome/Ptyxis/Profiles/%s/\n' "$uuid"
}

path="$(profile_path)" || { echo "ptyxis-theme: no default profile" >&2; exit 1; }

if [ "${1:-}" = "--show" ]; then
    echo "profile: $path"
    for key in font-name use-system-font interface-style disable-padding cursor-shape; do
        printf '  %-18s %s\n' "$key" "$(gsettings get "$SCHEMA" "$key" 2>/dev/null)"
    done
    for key in palette opacity bold-is-bright scrollback-lines; do
        printf '  %-18s %s\n' "$key" "$(gsettings get "$PROFILE_SCHEMA:$path" "$key" 2>/dev/null)"
    done
    exit 0
fi

set_app()     { gsettings set "$SCHEMA" "$1" "$2" || echo "ptyxis-theme: failed to set $1" >&2; }
set_profile() { gsettings set "$PROFILE_SCHEMA:$path" "$1" "$2" || echo "ptyxis-theme: failed to set $1" >&2; }

# --------------------------------------------------------------- appearance
set_app use-system-font   false
set_app font-name         "$FONT"
# Dark, unconditionally: the pywal palette is a dark one, and letting Ptyxis
# follow the system preference would pair a light chrome with dark colours.
set_app interface-style   "'dark'"
set_app cursor-shape      "'ibeam'"
set_app cursor-blink-mode "'on'"
# The default padding is generous; on a 1280x800 logical screen it costs real
# rows. `true` here means "no extra padding", matching the bar's compactness.
set_app disable-padding   true
set_app scrollbar-policy  "'never'"
set_app audible-bell      false
set_app visual-bell       true
set_app toast-on-copy-clipboard false

# ------------------------------------------------------------------ profile
if [ -f "$HOME/.local/share/org.gnome.Ptyxis/palettes/$PALETTE.palette" ]; then
    set_profile palette "'$PALETTE'"
else
    echo "ptyxis-theme: $PALETTE palette not installed yet -- set a wallpaper with" >&2
    echo "              waypaper first, that is what generates it. Leaving the" >&2
    echo "              current palette alone." >&2
fi

# Translucent, so the wallpaper shows through the way it does behind the bar's
# islands. Needs the compositor's blur to look right -- hyprland.conf enables it.
set_profile opacity          "$OPACITY"

# ------------------------------------------------------------------- shell
#
# Run fish instead of the login shell. Done here rather than with `chsh` so it
# needs no password and travels with the repo -- and so a broken fish can never
# lock you out of a login shell. `chsh -s $(command -v fish)` is still the right
# move if you want fish everywhere, not just in the terminal.
#
# Guarded: pointing Ptyxis at a command that does not exist gives you a window
# that opens and immediately dies, with no obvious cause.
if command -v fish >/dev/null 2>&1; then
    set_profile use-custom-command true
    set_profile custom-command "'$(command -v fish) --login'"
else
    echo "ptyxis-theme: fish is not installed -- leaving the shell alone." >&2
    echo "              install it, then re-run this script." >&2
fi
set_profile bold-is-bright   true
set_profile limit-scrollback false
set_profile scroll-on-output false
set_profile scroll-on-keystroke true

echo "ptyxis-theme: applied. Open a new window to see it."
