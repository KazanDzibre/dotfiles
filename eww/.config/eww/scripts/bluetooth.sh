#!/usr/bin/env bash
# Bluetooth state as JSON for the bar's bluetooth button.
#
#   {"powered":true,"connected":0,"devices":[{"mac":"..","name":"..",
#     "connected":false,"paired":true}]}
#
# `bluetoothctl devices` lists known (paired/trusted) devices; after a scan it
# also includes anything discovered nearby.

set -uo pipefail

powered="false"
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    powered="true"
fi

devices="[]"
if [ "$powered" = "true" ]; then
    devices="$(
        bluetoothctl devices 2>/dev/null \
        | while read -r _ mac name; do
              [ -n "$mac" ] || continue
              info="$(bluetoothctl info "$mac" 2>/dev/null)"
              conn="false"; grep -q "Connected: yes" <<<"$info" && conn="true"
              pair="false"; grep -q "Paired: yes"    <<<"$info" && pair="true"
              jq -nc --arg mac "$mac" --arg name "$name" \
                     --argjson conn "$conn" --argjson pair "$pair" \
                  '{mac:$mac, name:(if $name == "" then $mac else $name end),
                    connected:$conn, paired:$pair}'
          done \
        | jq -s 'sort_by(.connected == false, (.name | ascii_downcase))'
    )"
fi

jq -nc --argjson powered "$powered" --argjson devices "$devices" \
    '{powered:$powered, devices:$devices,
      connected:($devices | map(select(.connected)) | length)}'
