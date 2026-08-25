#!/usr/bin/env bash
# Actions for the bar's power menu.
#
#   power.sh lock | logout | reboot | shutdown
#
# The menu is closed first, so it is not left sitting on screen while the
# action runs (or frozen on the lock screen).

set -uo pipefail

action="${1:-}"

"$(dirname "$(readlink -f "$0")")/close-popups.sh"

case "$action" in
    lock)     exec "$HOME/.config/eww/scripts/lock.sh" ;;
    logout)   exec swaymsg exit ;;
    reboot)   exec systemctl reboot ;;
    shutdown) exec systemctl poweroff ;;
    *)
        echo "power: unknown action '$action' (want lock|logout|reboot|shutdown)" >&2
        exit 1
        ;;
esac
