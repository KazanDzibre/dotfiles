#!/usr/bin/env bash
# Battery state as JSON for the bar's battery module.
#
#   {"present":true,"pct":75,"status":"Charging","charging":true,"plugged":true,
#    "level":"normal","icon":"󰂉","time":"21 min","time_label":"until full",
#    "rate":"23.3 W","health":89,"energy":"25.5 Wh","energy_full":"33.8 Wh",
#    "cycles":130}
#
# Read from sysfs, not from `upower -i`: upower prints decimals in the user's
# locale ("25,4 Wh" here, sr_RS), which nothing downstream would parse back.
# sysfs is plain integers in micro-units and is locale-free.
#
# On a machine with no internal battery this still exits 0 with present:false;
# the widget hides itself on that, so the same config works on a desktop.

set -uo pipefail

bat=""
for d in /sys/class/power_supply/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] || continue
    # scope=Device is a peripheral's battery (bluetooth mouse, headset), not
    # the laptop's -- those appear here too and would otherwise win the loop.
    [ "$(cat "$d/scope" 2>/dev/null)" = "Device" ] && continue
    bat="$d"
    break
done

plugged=false
for d in /sys/class/power_supply/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = "Mains" ] || continue
    [ "$(cat "$d/online" 2>/dev/null)" = "1" ] && plugged=true
done

if [ -z "$bat" ]; then
    jq -nc --argjson plugged "$plugged" \
        '{present:false, pct:0, status:"None", charging:false, plugged:$plugged,
          level:"normal", icon:"󰂑", time:"", time_label:"", rate:"",
          health:0, energy:"", energy_full:"", cycles:0}'
    exit 0
fi

rd() { local v; v="$(cat "$bat/$1" 2>/dev/null)"; echo "${v:-0}"; }

pct="$(rd capacity)"
status="$(cat "$bat/status" 2>/dev/null)"
[ -n "$status" ] || status="Unknown"
cycles="$(rd cycle_count)"

# energy_* (uWh) on most laptops; some report charge_* (uAh) instead, which
# needs voltage to become energy. Normalise to uWh / uW here so the jq below
# only ever sees one shape.
now="$(rd energy_now)"
full="$(rd energy_full)"
design="$(rd energy_full_design)"
rate="$(rd power_now)"

if [ "$now" -eq 0 ] && [ "$(rd charge_now)" -ne 0 ]; then
    volt="$(rd voltage_now)"
    now=$(( $(rd charge_now)  * volt / 1000000 ))
    full=$(( $(rd charge_full) * volt / 1000000 ))
    design=$(( $(rd charge_full_design) * volt / 1000000 ))
    rate=$(( $(rd current_now) * volt / 1000000 ))
fi
rate=${rate#-}   # discharging reports a negative current on some firmware

jq -nc \
    --argjson pct "$pct" --arg status "$status" --argjson plugged "$plugged" \
    --argjson now "$now" --argjson full "$full" --argjson design "$design" \
    --argjson rate "$rate" --argjson cycles "$cycles" \
    '
    def wh: if . > 0 then ((. / 1000000 * 10 | round) / 10 | tostring) + " Wh" else "" end;

    ($status == "Charging") as $charging |

    # Minutes left: to full while charging, to empty while discharging.
    # power_now reads 0 for a few seconds after a state change, and on a full
    # battery -- no estimate is better than a divide-by-zero one.
    (if $rate <= 0 then 0
     elif $charging then (($full - $now) * 60 / $rate | round)
     elif $status == "Discharging" then ($now * 60 / $rate | round)
     else 0 end) as $mins |

    # 11 steps, 0..100 in tens; two sets so charging shows the bolt variant.
    (if $status == "Full" then "󰂄"
     elif $status == "Unknown" and $plugged then "󰂄"
     else
       (if $charging
        then ["󰢟","󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"]
        else ["󰂎","󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"] end
       )[($pct / 10 | round)]
     end) as $icon |

    {present: true,
     pct: $pct,
     status: $status,
     charging: $charging,
     plugged: $plugged,
     # Only ever "low"/"critical" on battery -- a red icon while charging at
     # 8% is alarming about a situation that is already resolving itself.
     level: (if $charging or $plugged then "normal"
             elif $pct <= 10 then "critical"
             elif $pct <= 20 then "low"
             else "normal" end),
     icon: $icon,
     time: (if $mins <= 0 then ""
            elif $mins < 60 then "\($mins) min"
            else "\($mins / 60 | floor)h \($mins % 60)m" end),
     time_label: (if $mins <= 0 then ""
                  elif $charging then "until full"
                  else "remaining" end),
     rate: (if $rate > 0 then ((($rate / 1000000) * 10 | round) / 10 | tostring) + " W" else "" end),
     health: (if $design > 0 then ($full * 100 / $design | round) else 0 end),
     energy: ($now | wh),
     energy_full: ($full | wh),
     cycles: $cycles}
    '
