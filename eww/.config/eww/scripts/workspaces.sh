#!/usr/bin/env bash
# Stream the sway workspace list as JSON: once at startup, then again on every
# change. Each bar instance filters this shared list down to its own output.
#
# Subscribing to "output" as well as "workspace" matters: on dock/undock sway
# moves workspaces between outputs without emitting a workspace event, and the
# bars would keep showing them on the screen they used to be on.

set -uo pipefail

emit() {
    swaymsg -t get_workspaces -r \
        | jq -c 'map({name, num, focused, urgent, output})'
}

emit
swaymsg -t subscribe -m '["workspace","output"]' | while read -r _; do
    emit
done
