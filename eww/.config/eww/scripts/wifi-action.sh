#!/usr/bin/env bash
# Wifi actions for the bar's network popup.
#
#   wifi-action.sh toggle             turn the wifi radio on/off
#   wifi-action.sh connect <ssid>     connect to a network
#   wifi-action.sh disconnect         drop the current wifi connection
#
# Connecting works without a prompt for open networks and for ones whose
# profile NetworkManager has already saved. A new secured network needs a
# password, which a bar popup has nowhere to type into -- that case hands off
# to nm-connection-editor (nm-applet is already running in this session).

set -uo pipefail

wifi_dev() {
    nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2 == "wifi" { print $1; exit }'
}

case "${1:-}" in
    toggle)
        if [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ]; then
            nmcli radio wifi off >/dev/null 2>&1
        else
            nmcli radio wifi on >/dev/null 2>&1
        fi
        ;;

    connect)
        ssid="${2:-}"
        [ -n "$ssid" ] || { echo "wifi-action: no ssid given" >&2; exit 1; }

        if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify-send -t 3000 "Wi-Fi" "Connected to $ssid" >/dev/null 2>&1
        else
            notify-send -u critical -t 6000 "Wi-Fi" \
                "Could not join $ssid — it probably needs a password" >/dev/null 2>&1
            setsid nm-connection-editor >/dev/null 2>&1 < /dev/null &
        fi
        ;;

    disconnect)
        dev="$(wifi_dev)"
        [ -n "$dev" ] && nmcli device disconnect "$dev" >/dev/null 2>&1
        ;;

    *)
        echo "wifi-action: unknown action '${1:-}' (want toggle|connect|disconnect)" >&2
        exit 1
        ;;
esac
