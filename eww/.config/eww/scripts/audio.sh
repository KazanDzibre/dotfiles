#!/usr/bin/env bash
# Stream audio state as JSON: output/input volume and mute, plus the list of
# available outputs so the popup can switch the default sink.
#
#   {"sink_vol":30,"sink_muted":false,"source_vol":27,"source_muted":false,
#    "sinks":[{"name":"alsa_output...","desc":"Built-in Audio","default":true}]}
#
# Event-driven off `pactl subscribe` -- polling PipeWire several times a second
# just to catch a volume keypress would be wasteful.

set -uo pipefail

state() {
    local sink_vol sink_muted source_vol source_muted default_sink sinks

    default_sink="$(pactl get-default-sink 2>/dev/null)"

    sink_vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
        | grep -oP '\d+(?=%)' | head -1)"
    source_vol="$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null \
        | grep -oP '\d+(?=%)' | head -1)"
    [ -n "$sink_vol" ] || sink_vol=0
    [ -n "$source_vol" ] || source_vol=0

    sink_muted="false"
    [ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null)" = "Mute: yes" ] && sink_muted="true"
    source_muted="false"
    [ "$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null)" = "Mute: yes" ] && source_muted="true"

    # Description rather than the node name: "Built-in Audio Analog Stereo"
    # reads better in a menu than "alsa_output.pci-0000_00_1f.3.analog-stereo".
    sinks="$(pactl -f json list sinks 2>/dev/null \
        | jq -c --arg def "$default_sink" \
            'map({name: .name,
                  desc: (.description // .name),
                  default: (.name == $def)})' 2>/dev/null)"
    [ -n "$sinks" ] || sinks="[]"

    jq -nc \
        --argjson sink_vol "$sink_vol" --argjson sink_muted "$sink_muted" \
        --argjson source_vol "$source_vol" --argjson source_muted "$source_muted" \
        --argjson sinks "$sinks" \
        '{sink_vol:$sink_vol, sink_muted:$sink_muted,
          source_vol:$source_vol, source_muted:$source_muted,
          sinks:$sinks}'
}

state

# `pactl subscribe` emits a line per change; sink/source/server events all
# matter (server covers the default-device switch).
pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
        *" on sink"*|*" on source"*|*" on server"*) state ;;
    esac
done
