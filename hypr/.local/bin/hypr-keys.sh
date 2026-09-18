#!/usr/bin/env bash
# Show every Hyprland keybind in rofi.
#
# Read from `hyprctl binds`, not from hyprland.conf, so it cannot drift: it
# lists what the compositor actually has, including binds that a later
# declaration shadowed. If a key you expect is missing here, it is missing in
# Hyprland too.
#
# Bound to Super+/ in hyprland.conf.

set -uo pipefail

command -v hyprctl >/dev/null 2>&1 || { echo "hypr-keys: not in a Hyprland session" >&2; exit 1; }
command -v jq      >/dev/null 2>&1 || { echo "hypr-keys: jq is required" >&2; exit 1; }

# Hyprland reports modifiers as a bitmask. These are the four that matter here;
# anything else falls through as its raw number so it is at least visible.
mods() {
    local m="$1" out=""
    (( m & 64 )) && out+="SUPER+"
    (( m & 1  )) && out+="SHIFT+"
    (( m & 4  )) && out+="CTRL+"
    (( m & 8  )) && out+="ALT+"
    [ -z "$out" ] && [ "$m" -ne 0 ] && out="mod${m}+"
    printf '%s' "$out"
}

list() {
    local modmask key dispatcher arg
    while IFS=$'\t' read -r modmask key dispatcher arg; do
        # A `global` dispatcher hands the key to another app (the Quickshell
        # bar); its arg is the shortcut name, which is more useful than "global".
        if [ "$dispatcher" = "global" ]; then
            printf '%-24s  %s\n' "$(mods "$modmask")${key}" "→ bar: ${arg#quickshell:}"
        else
            printf '%-24s  %s\n' "$(mods "$modmask")${key}" "${dispatcher}${arg:+ $arg}"
        fi
    done < <(hyprctl binds -j | jq -r '.[] | [.modmask, .key, .dispatcher, .arg] | @tsv') \
      | sort -u
}

if command -v rofi >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    # -dmenu with no selection action: this is a viewer, not a picker.
    list | rofi -dmenu -i -p "keybinds" -no-custom -theme-str 'window {width: 55%;}' >/dev/null
else
    list
fi
