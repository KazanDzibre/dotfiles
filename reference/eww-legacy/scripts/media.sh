#!/usr/bin/env bash

CACHE_BASE="/tmp/playerctl_cache_base"
CACHE_LAST="/tmp/playerctl_cache_last"

SKIP_FIRST=1 
has_skipped=0

# Use a default cover path
DEFAULT_COVER="$HOME/.config/eww/assets/pfp.png"

playerctl metadata \
    --format $'{{title}}\x1F{{artist}}\x1F{{album}}\x1F{{mpris:artUrl}}\x1F{{position}}\x1F{{mpris:length}}\x1F{{status}}' \
    --follow 2>/dev/null | while IFS=$'\x1F' read -r title artist album artUrl position length status; do

    # Handle empty metadata gracefully
    [[ -z "$title" ]] && title="No Media"
    [[ -z "$artist" ]] && artist=""
    [[ -z "$artUrl" || "$artUrl" == '""' ]] && artUrl="$DEFAULT_COVER"

    # Convert usec to seconds (using bc or printf to handle potential large ints safely)
    # If position/length are empty, default to 0
    pos_sec=$(printf "%.0f" "$(echo "(${position:-0} + 500000) / 1000000" | bc -l 2>/dev/null || echo 0)")
    len_sec=$(printf "%.0f" "$(echo "(${length:-0} + 500000) / 1000000" | bc -l 2>/dev/null || echo 0)")

    # 1. Smart startup skip
    if [[ "$has_skipped" -lt $SKIP_FIRST ]]; then
        if [[ "$status" == "Playing" && ($pos_sec -le 2 || $pos_sec -ge $((len_sec - 2))) && $len_sec -gt 10 ]]; then
            ((has_skipped++))
            continue
        fi
    fi

    # 2. If stopped or empty status
    if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
        rm -f "$CACHE_BASE" "$CACHE_LAST"
        jq -n -c \
            --arg art "$DEFAULT_COVER" \
            '{title: "No Media is Currently Playing", artist: "", album: "", artUrl: $art, position: 0, positionStr: "0:00", length: 0, lengthStr: "0:00", status: "Stopped"}'
        continue
    fi

    # 3. Paused state logic (Keep your logic, just clean the variable usage)
    if [[ "$status" == "Paused" ]]; then
        if [[ ! -f "$CACHE_BASE" ]]; then
            echo "$pos_sec" >"$CACHE_BASE"
            use_pos_sec=$pos_sec
        else
            base_pos=$(cat "$CACHE_BASE" 2>/dev/null || echo "$pos_sec")
            # Calculate absolute difference
            diff=$(( pos_sec > base_pos ? pos_sec - base_pos : base_pos - pos_sec ))
            
            if ((diff <= 3)); then
                use_pos_sec=$base_pos
            else
                echo "$pos_sec" >"$CACHE_BASE"
                use_pos_sec=$pos_sec
            fi
        fi
    else
        rm -f "$CACHE_BASE" "$CACHE_LAST"
        use_pos_sec=$pos_sec
    fi

    # Format time strings
    printf -v positionStr "%d:%02d" $((use_pos_sec / 60)) $((use_pos_sec % 60))
    printf -v lengthStr "%d:%02d" $((len_sec / 60)) $((len_sec % 60))

    # 4. Final JQ output using --arg for safety
    jq -n -c \
        --arg title "$title" \
        --arg artist "$artist" \
        --arg album "$album" \
        --arg artUrl "$artUrl" \
        --argjson position "$use_pos_sec" \
        --arg positionStr "$positionStr" \
        --argjson length "$len_sec" \
        --arg lengthStr "$lengthStr" \
        --arg status "$status" \
        '{
            title: $title,
            artist: $artist,
            album: $album,
            artUrl: $artUrl,
            position: $position,
            positionStr: $positionStr,
            length: $length,
            lengthStr: $lengthStr,
            status: $status
        }'
done
