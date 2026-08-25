#!/bin/bash

get_title() {
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        title=$(hyprctl activewindow -j | jq -r '.title' | sed 's/^null$/Desktop/')
    else
        # Sway logic: 
        # 1. Look for the focused node.
        # 2. Check if it has a 'shell' (Xwayland/Wayland window).
        # 3. If not, it's likely a workspace or empty area, so default to Desktop.
        title=$(swaymsg -t get_tree | jq -r '
            .. | select(.focused? == true) 
            | if .type == "con" or .type == "floating_con" then .name else "Desktop" end' \
            | sed 's/^null$/Desktop/')
    fi
    
    # Final safety check for empty strings
    if [[ -z "$title" ]]; then
        echo "Desktop"
    else
        echo "$title"
    fi
}

# Initial call
get_title

# Listen for focus/title changes
if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
    socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r line; do
        # activewindowv2 covers focus, titlechange covers... well, title changes
        if [[ $line =~ ^activewindowv2 ]] || [[ $line =~ ^windowtitle ]]; then
            get_title
        fi
    done
else
    # Sway subscription
    # We include 'window' for focus/closing and 'workspace' for switching to empty ones
    swaymsg -t subscribe '["window", "workspace"]' --monitor | while read -r _; do
        get_title
    done
fi
