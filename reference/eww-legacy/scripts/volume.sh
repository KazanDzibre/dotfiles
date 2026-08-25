#!/bin/bash
# ~/.config/eww/scripts/volume.sh

get_vol() {
    pamixer --get-volume-human
}

# Initial output
get_vol

# Listen for volume changes via pactl
pactl subscribe | stdbuf -oL grep --line-buffered "sink" | while read -r _; do
    get_vol
done
