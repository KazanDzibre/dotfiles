#!/usr/bin/env bash
# Lock the screen with the same look as the $mod+Shift+x binding in
# ~/.config/sway/config: pywal's current wallpaper, pywal's accent for the ring.
#
# Note: swaylock wants colours as RRGGBB with no leading '#', so the value read
# out of ~/.cache/wal/colors is stripped. (The sway binding passes the '#'
# through, and sway does not perform command substitution in `set` either, so
# that binding does not actually theme the ring.)

set -uo pipefail

WAL_CACHE="$HOME/.cache/wal"

accent="$(sed -n '2p' "$WAL_CACHE/colors" 2>/dev/null)"
accent="${accent#\#}"
[ -n "$accent" ] || accent="ffffff"

img="$(cat "$WAL_CACHE/wal" 2>/dev/null)"

if [ -f "$img" ]; then
    exec swaylock \
        -i "$img" \
        --scaling fill \
        --ring-color "$accent" \
        --key-hl-color "$accent" \
        --indicator-radius 100 \
        --indicator-thickness 7 \
        --inside-color 00000000 \
        --line-color 00000000
else
    exec swaylock -c 000000
fi
