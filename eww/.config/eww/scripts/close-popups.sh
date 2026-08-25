#!/usr/bin/env bash
# Close every popup and the click-catching backdrop, leaving the bars alone.
# Used by the backdrop's own click handler and by any action that should
# dismiss its menu (picking a wallpaper, choosing a power action).

set -uo pipefail

eww active-windows 2>/dev/null \
    | awk -F': ' '$2 != "bar" { print $1 }' \
    | while read -r id; do
          [ -n "$id" ] && eww close "$id" >/dev/null 2>&1
      done
