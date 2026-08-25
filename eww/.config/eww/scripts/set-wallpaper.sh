#!/usr/bin/env bash
# Apply a wallpaper through waypaper, which fires its post_command hook ->
# pywal regenerates the palette -> eww reloads with the new colours.
#
# Never call `wal` directly here: waypaper owns the wallpaper, and going behind
# its back leaves its config pointing at the wrong image after a --restore.

set -uo pipefail

# waypaper lives in ~/.local/bin, which is NOT on the eww daemon's PATH -- the
# daemon inherits sway's environment, not an interactive shell's. Resolving it
# by name works when testing from a terminal and then silently does nothing
# when the same script runs from a click, which is a miserable bug to chase.
WAYPAPER="$(command -v waypaper 2>/dev/null || true)"
[ -n "$WAYPAPER" ] || WAYPAPER="$HOME/.local/bin/waypaper"

img="${1:-}"
[ -f "$img" ] || { echo "set-wallpaper: no such image: $img" >&2; exit 1; }

if [ ! -x "$WAYPAPER" ]; then
    notify-send -u critical "Wallpaper" "waypaper not found at $WAYPAPER" >/dev/null 2>&1
    echo "set-wallpaper: waypaper not executable at $WAYPAPER" >&2
    exit 1
fi

# Close the picker (and its backdrop) first, so nothing is sitting on screen
# during the reload.
"$(dirname "$(readlink -f "$0")")/close-popups.sh"

# Detached: waypaper's hook ends in `eww reload`, and eww should not be waiting
# on the click handler that triggered it.
setsid "$WAYPAPER" --wallpaper "$img" >/dev/null 2>&1 < /dev/null &
