#!/usr/bin/env bash
# Regenerate the pywal palette from the newly selected wallpaper and make eww
# pick it up.
#
# Wired in via ~/.config/waypaper/config.ini:
#     post_command = /home/marko-ruzic/.config/waypaper/wallpaper_update.sh "$wallpaper"
#
# waypaper substitutes $wallpaper with the image it just applied.

set -uo pipefail

WAL="$HOME/.local/bin/wal"
COLORS="$HOME/.cache/wal/colors.scss"

img="${1:-}"
[ -n "$img" ] || { echo "wallpaper_update: no image argument" >&2; exit 1; }
[ -f "$img" ] || { echo "wallpaper_update: no such image: $img" >&2; exit 1; }
img="$(realpath "$img")"

# waypaper can fire the hook more than once for a single change (once per
# monitor with `monitors = All`). Without this, several `wal` runs race on
# ~/.cache/wal and eww reloads repeatedly.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/wallpaper_update.lock"
flock -n 9 || exit 0

# pywal records the source image in colors.scss; if it already matches, the
# palette is current and an eww reload would only cause a needless flicker.
current="$(sed -n 's/^\$wallpaper: "\(.*\)";$/\1/p' "$COLORS" 2>/dev/null)"
if [ "$current" = "$img" ]; then
    exit 0
fi

# -n: do not set the wallpaper, waypaper's backend already did that
# -q: quiet
# -e: do NOT reload gtk/xrdb/i3/sway/polybar. Without this pywal runs
#     `swaymsg reload`, which re-applies `output * bg #222222 solid_color` and
#     re-runs `exec_always waypaper --restore` -- leaving a second swaybg
#     stacked over the real wallpaper, and re-entering this very hook.
if ! "$WAL" -i "$img" -n -q -e; then
    echo "wallpaper_update: wal failed on $img" >&2
    exit 1
fi

# eww compiles the scss (and with it ~/.cache/wal/colors.scss) when the config
# loads, so new colours only appear after a reload.
if eww ping >/dev/null 2>&1; then
    eww reload
else
    setsid "$HOME/.config/eww/scripts/launch_bar.sh" >/dev/null 2>&1 < /dev/null &
fi
