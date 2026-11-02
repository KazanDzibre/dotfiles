#!/usr/bin/env bash
# Put the last wallpaper back at login. Run from hyprland.conf's exec-once.
#
# Why not `waypaper --restore`, which is what this replaced: at boot it
# silently failed some of the time. Two things combined to cause that:
#
#   * hyprpaper 0.8 dropped `preload` and `unload` from its IPC -- both now
#     answer "Unknown hyprpaper request". Only `wallpaper` still works.
#   * waypaper retries `hyprctl hyprpaper wallpaper` up to 10 times, but only
#     sleeps between attempts on the SUCCESS path. On failure it retries
#     immediately, so all ten burn in a few milliseconds. If hyprpaper's socket
#     is not listening yet -- and "the process exists" does not mean it is --
#     every attempt fails and waypaper gives up without a word.
#
# Fast boot: the socket is ready in time and it works. Slow boot: no wallpaper.
# This retries with an actual delay, against the one request that is known to
# work, and treats its exit status as the readiness signal.
#
# The palette is NOT regenerated here. pywal's output in ~/.cache/wal, the
# Hyprland colours and the Ptyxis palette all persist across reboots, so they
# already match the restored wallpaper.

set -uo pipefail

CONFIG="$HOME/.config/waypaper/config.ini"

# `^wallpaper *=` rather than `^wallpaper`: config.ini also has
# `wallpaperengine_folder = ...`, which a looser match would pick up.
img="$(sed -n 's/^wallpaper *= *//p' "$CONFIG" 2>/dev/null | head -1)"
img="${img/#\~/$HOME}"

[ -n "$img" ] || { echo "wallpaper_restore: no saved wallpaper in $CONFIG" >&2; exit 1; }
[ -f "$img" ] || { echo "wallpaper_restore: saved wallpaper is missing: $img" >&2; exit 1; }

pgrep -x hyprpaper >/dev/null || { hyprpaper >/dev/null 2>&1 & disown; }

# Up to ~10s. The empty monitor name before the comma means every output.
for attempt in $(seq 50); do
    if hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1; then
        [ -n "${VERBOSE:-}" ] && echo "wallpaper_restore: set on attempt $attempt" >&2
        exit 0
    fi
    sleep 0.2
done

echo "wallpaper_restore: hyprpaper never accepted the wallpaper after 10s" >&2
exit 1
