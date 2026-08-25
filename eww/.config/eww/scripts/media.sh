#!/usr/bin/env bash
# Stream the current MPRIS player state as JSON for the media button and popup.
#
#   {"status":"Playing","title":"..","artist":"..","album":"..","art":"/path",
#    "position":41,"length":215,"position_str":"0:41","length_str":"3:35",
#    "progress":19,"player":"spotify"}
#
# Polled once a second rather than `playerctl --follow`: --follow only fires on
# metadata changes, and the popup wants a progress bar that actually moves.

set -uo pipefail

CACHE="$HOME/.cache/eww/media"
mkdir -p "$CACHE"

# Album art is often a remote URL (Spotify, browser tabs). Fetch once and reuse
# the cached copy, keyed by the URL, so the 1s loop does not re-download.
art_path() {
    local url="$1" key dst
    case "$url" in
        file://*)
            local p="${url#file://}"
            [ -f "$p" ] && printf '%s' "$p"
            ;;
        http://*|https://*)
            key="$(printf '%s' "$url" | md5sum | cut -d' ' -f1)"
            dst="$CACHE/$key"
            if [ ! -s "$dst" ]; then
                curl -sfL --max-time 8 -o "$dst" "$url" 2>/dev/null || rm -f "$dst"
            fi
            [ -s "$dst" ] && printf '%s' "$dst"
            ;;
    esac
}

fmt_time() {
    local s="${1:-0}"
    [ "$s" -ge 0 ] 2>/dev/null || s=0
    printf '%d:%02d' $(( s / 60 )) $(( s % 60 ))
}

idle() {
    jq -nc '{status:"Stopped", title:"", artist:"", album:"", art:"",
             position:0, length:0, position_str:"0:00", length_str:"0:00",
             progress:0, player:""}'
}

while true; do
    status="$(playerctl status 2>/dev/null || true)"

    if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
        idle
        sleep 1
        continue
    fi

    # One metadata call for everything; \x1F cannot appear in a track title.
    IFS=$'\x1F' read -r player title artist album arturl len_us < <(
        playerctl metadata --format \
            $'{{playerName}}\x1F{{title}}\x1F{{artist}}\x1F{{album}}\x1F{{mpris:artUrl}}\x1F{{mpris:length}}' \
            2>/dev/null
    ) || true

    # mpris:length is microseconds; `playerctl position` is seconds as a float.
    len_us="${len_us:-0}"
    [[ "$len_us" =~ ^[0-9]+$ ]] || len_us=0
    length=$(( len_us / 1000000 ))

    position="$(playerctl position 2>/dev/null | cut -d. -f1)"
    [[ "$position" =~ ^[0-9]+$ ]] || position=0

    progress=0
    [ "$length" -gt 0 ] && progress=$(( position * 100 / length ))
    [ "$progress" -gt 100 ] && progress=100

    art="$(art_path "${arturl:-}")"

    jq -nc \
        --arg status "$status" --arg title "${title:-}" --arg artist "${artist:-}" \
        --arg album "${album:-}" --arg art "${art:-}" --arg player "${player:-}" \
        --argjson position "$position" --argjson length "$length" \
        --arg position_str "$(fmt_time "$position")" \
        --arg length_str "$(fmt_time "$length")" \
        --argjson progress "$progress" \
        '{status:$status, title:$title, artist:$artist, album:$album, art:$art,
          position:$position, length:$length, position_str:$position_str,
          length_str:$length_str, progress:$progress, player:$player}'

    sleep 1
done
