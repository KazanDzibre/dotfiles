#!/bin/bash

# --- Helper Functions ---

generate_hyprland() {
    active=$(hyprctl activeworkspace -j | jq '.id')
    echo -n "(box :class 'ws-container' :spacing 4 :space-evenly false "
    # Note: Removed :text '$id' and replaced with just '$id'
    hyprctl workspaces -j | jq -r '.[].id' | sort -n | while read -r id; do
        class=$([ "$id" -eq "$active" ] && echo "ws-active" || echo "ws-occupied")
        echo -n "(button :onclick 'hyprctl dispatch workspace $id' :class '$class' '$id')"
    done
    echo ")"
}

generate_sway() {
    ws_data=$(swaymsg -t get_workspaces)
    output="(box :class 'ws-container' :spacing 4 :space-evenly false "
    
    # Process the actual workspace names and focus status
    while read -r name focused; do
        class=$([ "$focused" == "true" ] && echo "ws-active" || echo "ws-occupied")
        # Use backslashes to escape quotes inside the string
        output+="(button :onclick \"swaymsg workspace $name\" :class \"$class\" \"$name\")"
    done < <(echo "$ws_data" | jq -r '.[] | "\(.name) \(.focused)"' | sort -n)
    
    output+=")"
    echo "$output"
}

# --- Main Logic ---

if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
    generate_hyprland
    socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r line; do
        case ${line%%>>*} in
            workspace|focusedmon|openwindow|closewindow|movewindow)
                generate_hyprland
                ;;
        esac
    done

elif [[ "$XDG_CURRENT_DESKTOP" == "sway" || "$XDG_CURRENT_DESKTOP" == "Sway" ]]; then
    generate_sway
    # We monitor workspace and window changes
    swaymsg -t subscribe '["workspace", "window"]' --monitor | while read -r line; do
        generate_sway
    done

else
    echo "(label :text 'Unknown Desktop')"
fi
