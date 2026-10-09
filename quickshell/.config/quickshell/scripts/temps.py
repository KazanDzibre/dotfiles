#!/usr/bin/env python3
"""Temperature sensors for the system panel.

Reads hwmon directly instead of shelling out to `sensors`, so there is no
lm-sensors dependency and no output format to parse.

hwmon numbering is not stable across boots -- hwmon8 is coretemp today and may
be something else tomorrow -- so devices are found by their `name` file on
every pass rather than by path. A pass is ~20 small sysfs reads, which is
cheaper than the subprocess it replaces.

Only sensors worth a row on a 290px card are reported: the CPU package (not its
16 per-core readings, which say the same thing), the GPU, each NVMe/SATA drive,
the battery, and the ACPI zone as a rough board temperature. Each carries the
chip's own warn/trip thresholds when the driver exposes them, since what counts
as hot is per-device -- a CPU at 85C is working, an NVMe at 85C is throttling.

Usage: temps.py            print one JSON object and exit (for testing)
       temps.py --watch 5  print one per 5s forever (how the bar runs it)
"""
import glob
import json
import os
import sys
import time

HWMON = "/sys/class/hwmon"

# hwmon `name` -> (key, label, default high, default crit). The defaults only
# apply when the driver exposes no temp*_max / temp*_crit of its own.
DEVICES = {
    "coretemp": ("cpu", "CPU", 85.0, 100.0),
    "k10temp": ("cpu", "CPU", 85.0, 100.0),
    "zenpower": ("cpu", "CPU", 85.0, 100.0),
    "amdgpu": ("gpu", "GPU", 85.0, 95.0),
    "nvidia": ("gpu", "GPU", 85.0, 95.0),
    "radeon": ("gpu", "GPU", 85.0, 95.0),
    "i915": ("gpu", "GPU", 85.0, 95.0),
    "xe": ("gpu", "GPU", 85.0, 95.0),
    "nvme": ("nvme", "NVMe", 70.0, 85.0),
    "drivetemp": ("disk", "Disk", 55.0, 65.0),
}

# The label a multi-sensor chip reports for the reading that represents the
# whole part. Everything else on that chip is skipped.
PRIMARY_LABELS = {
    "cpu": ("package id 0", "tctl", "tdie", "cpu"),
    "gpu": ("edge", "gpu"),
    "nvme": ("composite",),
}


def read(path):
    try:
        with open(path) as handle:
            return handle.read().strip()
    except OSError:
        return None


def millidegrees(path):
    raw = read(path)
    if raw is None:
        return None
    try:
        value = int(raw) / 1000.0
    except ValueError:
        return None
    # Unpopulated sensors park at an obvious sentinel (-274C is the usual one).
    return value if -40.0 < value < 200.0 else None


def threshold(prefix, suffix, fallback):
    value = millidegrees(f"{prefix}_{suffix}")
    return value if value is not None else fallback


def pick(chip, key):
    """The one temp*_input on this chip that stands for the whole device."""
    inputs = sorted(glob.glob(f"{chip}/temp*_input"))
    if not inputs:
        return None

    wanted = PRIMARY_LABELS.get(key, ())
    for path in inputs:
        label = (read(path.replace("_input", "_label")) or "").lower()
        if label in wanted:
            return path
    # No label matched: temp1 is the summary reading on every driver seen here.
    return inputs[0]


def collect():
    sensors = []
    seen = {}

    for chip in sorted(glob.glob(f"{HWMON}/hwmon*")):
        name = read(f"{chip}/name") or ""

        entry = DEVICES.get(name)
        if entry is None:
            # Battery packs report as BAT0, BAT1, ... and mostly carry no
            # temperature at all; the read below drops them when they do not.
            if name.startswith("BAT"):
                entry = ("battery", "Battery", 50.0, 60.0)
            else:
                continue

        key, label, high, crit = entry
        path = pick(chip, key)
        if path is None:
            continue
        temp = millidegrees(path)
        if temp is None:
            continue

        # Two NVMe drives both want to be called "NVMe"; number them.
        seen[key] = seen.get(key, 0) + 1
        if seen[key] > 1:
            label = f"{label} {seen[key]}"

        prefix = path[: -len("_input")]
        sensors.append({
            "key": key if seen[key] == 1 else f"{key}{seen[key]}",
            "label": label,
            "temp": round(temp, 1),
            "high": threshold(prefix, "max", high),
            "crit": threshold(prefix, "crit", crit),
        })

    if not any(s["key"] == "cpu" for s in sensors):
        # No coretemp/k10temp loaded. x86_pkg_temp is the same package sensor
        # reached through the thermal framework; failing that, the hottest ACPI
        # zone is the closest thing the machine admits to a CPU reading.
        fallback = zone_temp("x86_pkg_temp") or zone_temp("acpitz")
        if fallback is not None:
            sensors.append({
                "key": "cpu",
                "label": "CPU (ACPI)",
                "temp": fallback,
                "high": 85.0,
                "crit": 100.0,
            })

    board = zone_temp("acpitz")
    if board is not None and board_is_distinct(board, sensors):
        sensors.append({
            "key": "board",
            "label": "Board",
            "temp": board,
            "high": 70.0,
            "crit": 90.0,
        })

    # hwmon order is alphabetical by chip number, which puts the NVMe above the
    # CPU. Present them in the order they matter instead.
    rank = {"cpu": 0, "gpu": 1, "nvme": 2, "disk": 3, "battery": 4, "board": 5}
    sensors.sort(key=lambda s: (rank.get(s["key"].rstrip("0123456789"), 9), s["label"]))
    return {"sensors": sensors}


def board_is_distinct(board, sensors):
    """Whether the ACPI zone says anything the CPU row does not.

    On many laptops -- this one included -- acpitz simply mirrors the CPU
    package, and a second row reading the same number is noise. The decision is
    made once, on the first pass, and then cached: a row that appeared and
    vanished as the two readings drifted past each other would be worse than
    either answer.
    """
    if "distinct" not in _BOARD:
        cpu = next((s["temp"] for s in sensors if s["key"] == "cpu"), None)
        _BOARD["distinct"] = cpu is None or abs(board - cpu) >= 3.0
    return _BOARD["distinct"]


_BOARD = {}


def zone_temp(kind):
    """The hottest /sys/class/thermal zone of this type, or None."""
    temps = []
    for zone in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
        if not (read(f"{zone}/type") or "").lower().startswith(kind):
            continue
        temp = millidegrees(f"{zone}/temp")
        if temp is not None:
            temps.append(temp)
    return round(max(temps), 1) if temps else None


def main():
    interval = 0.0
    argv = sys.argv[1:]
    if argv and argv[0] == "--watch":
        interval = float(argv[1]) if len(argv) > 1 else 5.0

    if not os.path.isdir(HWMON):
        print(json.dumps({"sensors": [], "error": "no hwmon"}), flush=True)
        return

    while True:
        try:
            print(json.dumps(collect()), flush=True)
        except BrokenPipeError:
            # The bar went away. Nothing to report it to, so just stop.
            return
        if interval <= 0:
            return
        time.sleep(interval)


if __name__ == "__main__":
    main()
