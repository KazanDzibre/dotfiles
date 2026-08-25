#!/usr/bin/env bash
# Open one eww bar per connected sway output, and keep them in sync as displays
# come and go (dock, undock, cable pull).
#
# Why a script instead of one defwindow per monitor:
#   - a defwindow naming a monitor that is not connected fails to open, so a
#     static bar0/bar1/bar2 breaks the moment you are on the laptop alone;
#   - numeric :monitor indices are GTK's ordering, which differs from sway's
#     and is renumbered on every hotplug.
# So the bar is defined once in eww.yuck and instanced here, keyed by the
# output's connector name.
#
# Started from ~/.config/sway/config:  exec --no-startup-id ~/.config/eww/scripts/launch_bar.sh

set -uo pipefail

WINDOW="bar"
PREFIX="bar-"

# Single instance only. Without this, a sway reload or a second manual run leaves
# several hotplug watchers alive, and they all race to reconcile on the same
# output event -- duplicate `eww open` calls, spurious failures in the log.
#
# A pidfile rather than flock: a lock fd opened here is inherited by every child,
# and `eww daemon` outlives this script -- so the daemon would keep holding the
# lock forever and no later run of this script could ever start.
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/eww-launch_bar.pid"

already_running() {
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null)" || return 1
    [ -n "$pid" ] && [ "$pid" != "$$" ] || return 1
    # Guard against a recycled pid belonging to something else entirely.
    grep -qa "launch_bar" "/proc/$pid/cmdline" 2>/dev/null
}

if already_running; then
    echo "launch_bar: already running (pid $(cat "$PIDFILE")), nothing to do" >&2
    exit 0
fi

echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# Connector names of outputs that are actually usable right now.
outputs() {
    swaymsg -t get_outputs -r | jq -r '.[] | select(.active) | .name'
}

# Ids of bar instances eww currently has open. `eww active-windows` prints
# lines of "<id>: <window_name>".
live_ids() {
    eww active-windows 2>/dev/null | awk -F': ' -v w="$WINDOW" '$2 == w { print $1 }'
}

# Bring the daemon up if it is not answering. Called before every reconcile, so
# a daemon that died (crash, manual `eww kill`) is restored on the next output
# event instead of leaving the session with no bars at all.
ensure_daemon() {
    eww ping >/dev/null 2>&1 && return 0

    eww daemon >/dev/null 2>&1
    for _ in $(seq 20); do
        eww ping >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "launch_bar: daemon did not come up" >&2
    return 1
}

reconcile() {
    local wanted live out id

    ensure_daemon || return 1
    wanted="$(outputs | sed "s|^|${PREFIX}|")"
    live="$(live_ids)"

    # Close bars whose output disappeared.
    while read -r id; do
        [ -n "$id" ] || continue
        grep -qxF "$id" <<<"$wanted" || eww close "$id" >/dev/null 2>&1
    done <<<"$live"

    # Open bars for outputs that do not have one yet.
    while read -r out; do
        [ -n "$out" ] || continue
        id="${PREFIX}${out}"
        grep -qxF "$id" <<<"$live" && continue
        # --arg output=... lets the bar show only this output's workspaces.
        eww open "$WINDOW" --id "$id" --screen "$out" --arg "output=$out" >/dev/null 2>&1 \
            || echo "launch_bar: failed to open $id on $out" >&2
    done < <(outputs)
}

reconcile

# sway emits an `output` event on connect, disconnect and mode change. The read
# also times out periodically, so reconcile still runs when nothing has been
# plugged in -- that is what lets a crashed daemon come back without a hotplug.
while true; do
    while true; do
        read -r -t 30 _
        rc=$?
        if [ "$rc" -eq 0 ]; then
            sleep 0.3   # let sway finish applying the new layout before asking eww
        elif [ "$rc" -le 128 ]; then
            break       # not a timeout: the subscription ended
        fi
        reconcile
    done < <(swaymsg -t subscribe -m '["output"]')

    echo "launch_bar: sway output subscription ended, restarting" >&2
    sleep 2
done
