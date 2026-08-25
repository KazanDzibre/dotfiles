#!/usr/bin/env bash
# Current network state as JSON for the bar's network button.
#
#   {"type":"ethernet"|"wifi"|"none","label":"LAN","signal":0,"wifi_enabled":true}
#
# Ethernet wins when both are up: if the cable is in, that is the connection
# actually carrying traffic.

set -uo pipefail

status="$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null)"

eth="$(awk -F: '$1 == "ethernet" && $2 == "connected" { print $3; exit }' <<<"$status")"
wifi="$(awk -F: '$1 == "wifi" && $2 == "connected" { print $3; exit }' <<<"$status")"

enabled="false"
[ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ] && enabled="true"

if [ -n "$eth" ]; then
    jq -nc --argjson en "$enabled" \
        '{type:"ethernet", label:"LAN", signal:0, wifi_enabled:$en}'
elif [ -n "$wifi" ]; then
    signal="$(nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null \
        | awk -F: '$1 == "*" { print $2; exit }')"
    [ -n "$signal" ] || signal=0
    jq -nc --arg label "$wifi" --argjson sig "$signal" --argjson en "$enabled" \
        '{type:"wifi", label:$label, signal:$sig, wifi_enabled:$en}'
else
    jq -nc --argjson en "$enabled" \
        '{type:"none", label:"Offline", signal:0, wifi_enabled:$en}'
fi
