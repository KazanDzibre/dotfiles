#!/usr/bin/env bash
# Bluetooth actions for the bar's bluetooth popup.
#
#   bt-action.sh toggle              turn the adapter on/off
#   bt-action.sh scan                discover nearby devices for a while
#   bt-action.sh device <mac>        connect, or disconnect if already connected

set -uo pipefail

powered() { bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; }

case "${1:-}" in
    toggle)
        if powered; then
            bluetoothctl power off >/dev/null 2>&1
        else
            # The adapter on this laptop comes up rfkill soft-blocked, and
            # `bluetoothctl power on` cannot clear that by itself.
            rfkill unblock bluetooth >/dev/null 2>&1
            sleep 0.5
            bluetoothctl power on >/dev/null 2>&1
        fi
        ;;

    scan)
        powered || exit 0
        notify-send -t 3000 "Bluetooth" "Scanning for devices…" >/dev/null 2>&1
        # Blocking scan: discovered devices then show up in `bluetoothctl devices`,
        # which the popup polls.
        bluetoothctl --timeout 12 scan on >/dev/null 2>&1
        notify-send -t 3000 "Bluetooth" "Scan finished" >/dev/null 2>&1
        ;;

    device)
        mac="${2:-}"
        [ -n "$mac" ] || { echo "bt-action: no device given" >&2; exit 1; }

        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            bluetoothctl disconnect "$mac" >/dev/null 2>&1
        else
            # Pair first if this device is not known yet; already-paired
            # devices just return an error here, which is fine.
            bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes" \
                || bluetoothctl pair "$mac" >/dev/null 2>&1
            bluetoothctl trust "$mac" >/dev/null 2>&1
            if ! bluetoothctl connect "$mac" >/dev/null 2>&1; then
                notify-send -u critical "Bluetooth" "Could not connect to $mac" >/dev/null 2>&1
            fi
        fi
        ;;

    *)
        echo "bt-action: unknown action '${1:-}' (want toggle|scan|device)" >&2
        exit 1
        ;;
esac
