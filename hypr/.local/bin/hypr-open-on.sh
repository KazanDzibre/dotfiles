#!/usr/bin/env bash
# Launch an app and send its first new window to a workspace, without following
# it there.
#
#   hypr-open-on.sh <workspace> <class-regex> <command> [args...]
#   hypr-open-on.sh 9 '^chromium$' chromium          (exec-once in hyprland.conf)
#
# Why not `exec-once = [workspace 9 silent] chromium`, which is what that syntax
# is for: Hyprland 0.53 matches an exec rule by an HL_EXEC_RULE_TOKEN variable
# it puts in the launched command's environment and later reads back from the
# window's process. Snap starts the app with that variable stripped, so for a
# snap (Chromium, Slack) the rule never matches and the window opens wherever
# focus is. Verified: the token is on the `sh -c` Hyprland spawned, and absent
# from the chrome process that owns the window.
#
# Why not a window rule: it moves EVERY window of the class. Slack has one
# window, so it does use a rule; Chromium must only have its first window moved.
#
# So: note the windows of that class that already exist, launch, wait for one
# that was not there before, move it. The window shows on the focused workspace
# for a moment before it moves -- the cost of placing it after the fact.

set -uo pipefail

me=hypr-open-on

if [ $# -lt 3 ]; then
    echo "$me: usage: $me <workspace> <class-regex> <command> [args...]" >&2
    exit 2
fi
command -v hyprctl >/dev/null 2>&1 || { echo "$me: not in a Hyprland session" >&2; exit 1; }
command -v jq      >/dev/null 2>&1 || { echo "$me: jq is required" >&2; exit 1; }

ws="$1" class="$2"
shift 2

# A cold snap start at login takes several seconds; allow a minute.
tries=120 interval=0.5

before=$(hyprctl clients -j | jq -c --arg c "$class" '[.[] | select(.class | test($c)) | .address]')

"$@" >/dev/null 2>&1 &
disown

for _ in $(seq "$tries"); do
    addr=$(hyprctl clients -j | jq -r --arg c "$class" --argjson old "$before" '
        [.[] | select((.class | test($c)) and (.address as $a | $old | index($a) | not))]
        | first | .address // empty')
    if [ -n "$addr" ]; then
        # Out of any tab group first. With group:auto_group on, a window that
        # opens on a stacked workspace (SUPER+W) joins that group, and moving
        # one member moves the WHOLE group -- which once carried Teams and
        # Slack off to 9 along with Chromium.
        if hyprctl clients -j | jq -e --arg a "$addr" \
            '.[] | select(.address == $a) | .grouped | length > 0' >/dev/null; then
            hyprctl dispatch moveoutofgroup "address:$addr" >/dev/null
        fi
        hyprctl dispatch movetoworkspacesilent "$ws,address:$addr" >/dev/null
        exit 0
    fi
    sleep "$interval"
done

echo "$me: no new '$class' window after $((tries / 2))s; left it where it opened" >&2
exit 1
