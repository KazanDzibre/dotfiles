#!/usr/bin/env bash
# Toggle a popup window on whichever output currently has focus, so it appears
# under the bar the user actually clicked. Only one popup exists at a time.
#
#   toggle-popup.sh <window-name>
#
# Instances are named "<window-name>-<output>", matching the bar's own
# "bar-<output>" convention.
#
# Opening a popup also opens `popup_backdrop` on every connected output: a
# full-screen, fully transparent window that closes everything when clicked.
# That is what makes a click outside the popup dismiss it. The backdrop is
# opened FIRST so the popup stacks above it -- among windows on the same
# layer-shell layer, the one created later is on top.

set -uo pipefail

win="${1:-}"
[ -n "$win" ] || { echo "toggle-popup: no window name given" >&2; exit 1; }

scripts="$(dirname "$(readlink -f "$0")")"

outputs() {
    swaymsg -t get_outputs -r | jq -r '.[] | select(.active) | .name'
}

out="$(swaymsg -t get_outputs -r | jq -r '.[] | select(.focused) | .name')"
[ -n "$out" ] || out="$(outputs | head -1)"
[ -n "$out" ] || exit 0

id="${win}-${out}"
open_ids="$(eww active-windows 2>/dev/null | awk -F': ' -v w="$win" '$2 == w { print $1 }')"

if grep -qxF "$id" <<<"$open_ids"; then
    # Clicking the same button again closes it.
    "$scripts/close-popups.sh"
else
    # Drop whatever was open (including a backdrop from a previous popup).
    "$scripts/close-popups.sh"

    while read -r o; do
        [ -n "$o" ] || continue
        eww open popup_backdrop --id "backdrop-$o" --screen "$o" >/dev/null 2>&1
    done < <(outputs)

    eww open "$win" --id "$id" --screen "$out"
fi
