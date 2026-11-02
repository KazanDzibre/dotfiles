#!/usr/bin/env bash
# Sway-style tabbed layout for Hyprland.
#
#   hypr-stack.sh on    SUPER+W   every tiled window on this workspace -> one
#                                 tabbed group     (sway: `layout tabbed`)
#   hypr-stack.sh off   SUPER+E   dissolve it back to normal tiling
#                                                  (sway: `layout toggle split`)
#   hypr-stack.sh move l|r        SUPER+SHIFT+h/l  move the current tab left or
#                                 right; outside a group, the master-layout swap
#                                 these keys always did
#
# Hyprland has no stacking/tabbed *layout*. What it has is groups: a window can
# hold several windows as tabs, drawn with a groupbar. So "tab the workspace"
# means building one group out of every tiled window on it. Sway's own default
# for Mod+W is tabbed, not stacking; Hyprland only has the tabbed kind anyway.
#
# How the group is built, and why this way -- every simpler version was tested
# in a nested Hyprland and failed:
#
#   * NOT by grouping the focused window and moving the rest back in. auto_group
#     only absorbs newly *created* windows; moved windows stay separate.
#   * NOT with a fixed direction (group the master, `moveintogroup l` the rest).
#     That works on a fresh layout, but after a dissolve the master layout comes
#     back MIRRORED -- full-height window on the right, two stacked on the left
#     -- so "left" points at the wrong thing and nothing merges.
#   * YES by convergence: start the group on the focused window, then for every
#     window still outside it, try `moveintogroup` in all four directions. A
#     direction with no group next to it is a no-op, so trying all four is
#     safe. Each merge grows the group, so a window that was not adjacent on one
#     pass is on the next. Repeat until nothing is left or a pass changes
#     nothing. No assumption about layout, orientation or window order.
#
# Tabs are switched with SUPER+h/l, because binds:movefocus_cycles_groupfirst
# makes movefocus walk the group's tabs before leaving it -- sway's behaviour.

set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "hypr-stack: jq is required" >&2; exit 1; }

d() { hyprctl dispatch "$@" >/dev/null; }

ws=$(hyprctl activeworkspace -j | jq '.id')
orig=$(hyprctl activewindow -j | jq -r '.address // empty')

# Tiled windows on this workspace. Floating ones (the AI panel, dialogs) and
# fullscreen ones are left alone: they are not part of the tiling to stack.
tiled_json=$(hyprctl clients -j | jq --argjson ws "$ws" \
    '[.[] | select(.workspace.id == $ws and .floating == false and .fullscreen == 0)]')

case "${1:-}" in
on)
    [ "$(jq 'length' <<<"$tiled_json")" -ge 1 ] || exit 0

    # Seed the group on the window you were on, if it is tiled; otherwise on
    # any tiled window.
    seed=$(jq -r --arg o "$orig" '([.[] | select(.address == $o)] + .)[0].address' <<<"$tiled_json")
    grouped_now() {
        hyprctl clients -j | jq -r --argjson ws "$ws" --arg a "$1" \
            '.[] | select(.workspace.id == $ws and .address == $a) | (.grouped | length)'
    }

    # Idempotent: a second SUPER+W must not dissolve the group, which is what
    # togglegroup on an already-grouped window would do.
    if [ "$(grouped_now "$seed")" -eq 0 ]; then
        d focuswindow "address:$seed"
        d togglegroup
    fi

    # Converge. Bounded, so a window that genuinely cannot reach the group
    # (it should not happen, but tiling is not our code) cannot loop forever.
    for _pass in 1 2 3 4 5 6; do
        outside=$(hyprctl clients -j | jq -r --argjson ws "$ws" \
            '.[] | select(.workspace.id == $ws and .floating == false and .fullscreen == 0 and (.grouped | length) == 0) | .address')
        [ -n "$outside" ] || break

        progress=0
        for a in $outside; do
            for dir in l r u d; do
                d focuswindow "address:$a"
                d moveintogroup "$dir"
                if [ "$(grouped_now "$a")" -gt 0 ]; then
                    progress=1
                    break
                fi
            done
        done
        [ "$progress" -eq 1 ] || break
    done

    # Put the window you were on back in front. Focusing a group member makes
    # it the visible tab.
    [ -n "$orig" ] && d focuswindow "address:$orig"
    ;;

off)
    # Usually the focused window is the group. If focus is on something
    # floating, find the group among the tiled windows instead.
    target=$(hyprctl activewindow -j | jq -r 'select((.grouped | length) > 0) | .address // empty')
    [ -n "$target" ] || target=$(jq -r '[.[] | select((.grouped | length) > 0)][0].address // empty' <<<"$tiled_json")
    [ -n "$target" ] || exit 0

    d focuswindow "address:$target"
    d togglegroup          # on a group, this dissolves the whole thing
    [ -n "$orig" ] && d focuswindow "address:$orig"
    ;;

move)
    # SUPER+SHIFT+h/l already meant something before tabs existed -- swap with
    # master / swap with next in the master layout -- and Hyprland binds cannot
    # branch on state. So the branch lives here: reorder tabs inside a group,
    # otherwise do exactly what the keys did before.
    #
    # Clamped at the ends on purpose. `movegroupwindow` wraps, so moving right
    # from the last tab would fling it to the front; sway never wraps, and a
    # key that does nothing at the edge is less surprising than one that jumps.
    aw=$(hyprctl activewindow -j)
    n=$(jq '.grouped | length' <<<"$aw")

    if [ "$n" -gt 1 ]; then
        pos=$(jq '.address as $a | .grouped | index($a)' <<<"$aw")
        case "${2:-}" in
            l) if [ "$pos" -gt 0 ];            then d movegroupwindow b; fi ;;
            r) if [ "$pos" -lt $((n - 1)) ];   then d movegroupwindow f; fi ;;
            *) echo "usage: hypr-stack.sh move l|r" >&2; exit 2 ;;
        esac
    else
        case "${2:-}" in
            l) d layoutmsg swapwithmaster ;;
            r) d layoutmsg swapnext ;;
            *) echo "usage: hypr-stack.sh move l|r" >&2; exit 2 ;;
        esac
    fi
    ;;

*)
    echo "usage: hypr-stack.sh on|off|move l|r" >&2
    exit 2
    ;;
esac
