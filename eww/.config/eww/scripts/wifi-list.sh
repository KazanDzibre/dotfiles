#!/usr/bin/env bash
# Visible wifi networks as a JSON array, strongest first.
#
# Reads NetworkManager's cached scan (no --rescan), so this is cheap enough to
# poll while the popup is closed. nmcli refreshes that cache on its own.

set -uo pipefail

# -t makes output colon-separated and escapes any colon inside a field as "\:".
# Those are swapped for a sentinel before splitting and restored afterwards, so
# an SSID containing a colon survives (a plain space in an SSID is untouched).
nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
    | jq -R -s '
        split("\n")
        | map(select(length > 0))
        | map(
            gsub("\\\\:"; "@@COLON@@")
            | split(":")
            | map(gsub("@@COLON@@"; ":"))
            | {
                active:   (.[0] == "*"),
                ssid:     (.[1] // ""),
                signal:   (.[2] | tonumber? // 0),
                security: (.[3] // ""),
                open:     ((.[3] // "") == "")
              }
          )
        | map(select(.ssid != ""))
        | unique_by(.ssid)
        | sort_by(-.signal)
    '
