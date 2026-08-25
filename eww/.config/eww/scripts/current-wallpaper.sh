#!/usr/bin/env bash
# Path of the wallpaper pywal last generated the palette from. Used by the
# picker to mark which thumbnail is currently applied.
sed -n 's/^\$wallpaper: "\(.*\)";$/\1/p' "$HOME/.cache/wal/colors.scss" 2>/dev/null
