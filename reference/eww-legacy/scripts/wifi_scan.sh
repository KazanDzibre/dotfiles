#!/bin/bash

# Get list of SSIDs, signal strength, and security
# Format: SSID:SIGNAL:SECURITY
nmcli -t -f SSID,BARS,SECURITY dev wifi list | head -n 8 | while read -r line; do
    ssid=$(echo "$line" | cut -d: -f1)
    signal=$(echo "$line" | cut -d: -f2)
    
    if [ -n "$ssid" ]; then
        # Output a button for each network
        echo "(button :class 'wifi-item' :onclick 'nmcli dev wifi connect \"$ssid\"' 
                (box :space-evenly false :spacing 10
                    (label :text '󰖩 ' :class 'wifi-list-icon')
                    (label :text '$ssid' :limit-width 15)
                    (label :text '$signal' :halign 'end' :hexpand true)))"
    fi
done
