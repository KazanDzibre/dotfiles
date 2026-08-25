#!/usr/bin/env bash
# Stream CPU / RAM / disk usage as JSON, once every few seconds.
#
#   {"cpu":12,"ram_pct":38,"ram_used":"5.9G","ram_total":"15Gi",
#    "disk_pct":61,"disk_used":"140G","disk_total":"235G"}
#
# This is a deflisten rather than a defpoll because CPU load is a *delta*: it
# needs two /proc/stat samples, so the previous one has to be kept between
# ticks. A defpoll would have to sleep inside every invocation instead.

set -uo pipefail

INTERVAL=3

prev_total=0
prev_idle=0

cpu_pct() {
    # /proc/stat first line: cpu user nice system idle iowait irq softirq steal
    local -a f
    read -r _ f0 f1 f2 f3 f4 f5 f6 f7 _ < /proc/stat
    f=("$f0" "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7")

    local total=0 idle
    for v in "${f[@]}"; do
        total=$(( total + ${v:-0} ))
    done
    idle=$(( ${f[3]:-0} + ${f[4]:-0} ))   # idle + iowait

    local d_total=$(( total - prev_total ))
    local d_idle=$(( idle - prev_idle ))
    prev_total=$total
    prev_idle=$idle

    if [ "$d_total" -le 0 ]; then
        echo 0
    else
        echo $(( (100 * (d_total - d_idle)) / d_total ))
    fi
}

# Prime the CPU counters so the first emitted sample is a real delta.
cpu_pct > /dev/null
sleep 0.3

while true; do
    cpu="$(cpu_pct)"

    read -r ram_used ram_total ram_pct < <(
        free -b | awk '/^Mem:/ { printf "%s %s %d", $3, $2, ($3 * 100 / $2) }'
    )
    read -r disk_used disk_total disk_pct < <(
        df -B1 --output=used,size / | awk 'NR == 2 { printf "%s %s %d", $1, $2, ($1 * 100 / $2) }'
    )

    jq -nc \
        --argjson cpu "$cpu" \
        --argjson ram_pct "$ram_pct" --argjson ram_used "$ram_used" --argjson ram_total "$ram_total" \
        --argjson disk_pct "$disk_pct" --argjson disk_used "$disk_used" --argjson disk_total "$disk_total" \
        'def human:
             if   . >= 1073741824 then (. / 1073741824 * 10 | round / 10 | tostring) + "G"
             elif . >= 1048576    then (. / 1048576    | round | tostring) + "M"
             else (. / 1024 | round | tostring) + "K" end;
         {cpu: $cpu,
          ram_pct: $ram_pct,   ram_used: ($ram_used | human),   ram_total: ($ram_total | human),
          disk_pct: $disk_pct, disk_used: ($disk_used | human), disk_total: ($disk_total | human)}'

    sleep "$INTERVAL"
done
