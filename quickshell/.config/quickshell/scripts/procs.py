#!/usr/bin/env python3
"""procs.py — the heaviest of your own processes right now, grouped by name.

Samples /proc twice, half a second apart, so the CPU figure is what a
program is using at this moment (ps only reports a lifetime average). Prints
a JSON list: {name, pids, count, cpu (percent of one core), rssMb}.
Used by the island's `kill` search; system services and the shell itself are
left out so a stray Enter can't take the desktop down.
"""
import json
import os
import time

PROTECTED = {
    "systemd", "(sd-pam)", "dbus-daemon", "dbus-broker", "pipewire", "pipewire-pulse",
    "wireplumber", "Hyprland", "hyprland", "quickshell", "qs", "python3", "ps", "sh",
    "bash", "claude", "login", "sddm", "gdm", "polkit-gnome-au", "xdg-desktop-por", "gnome-keyring-d",
}

HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
UID = os.getuid()
ME = os.getpid()


def sample():
    out = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        if pid == ME:
            continue
        try:
            if os.stat(f"/proc/{pid}").st_uid != UID:
                continue
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
            # The name sits in parentheses and may contain spaces.
            rest = stat[stat.rindex(")") + 2:].split()
            ticks = int(rest[11]) + int(rest[12])
            with open(f"/proc/{pid}/statm") as f:
                rss = int(f.read().split()[1]) * PAGE
            with open(f"/proc/{pid}/comm") as f:
                name = f.read().strip()
        except (OSError, ValueError, IndexError):
            continue
        out[pid] = (name, ticks, rss)
    return out


first = sample()
t0 = time.monotonic()
time.sleep(0.5)
second = sample()
dt = max(time.monotonic() - t0, 0.001)

groups = {}
for pid, (name, ticks, rss) in second.items():
    if name in PROTECTED:
        continue
    before = first.get(pid)
    cpu = ((ticks - before[1]) / HZ / dt * 100) if before else 0.0
    g = groups.setdefault(name, {"name": name, "pids": [], "count": 0, "cpu": 0.0, "rssMb": 0.0})
    g["pids"].append(pid)
    g["count"] += 1
    g["cpu"] += max(cpu, 0.0)
    g["rssMb"] += rss / 1048576

rows = list(groups.values())
# A hundred megabytes weighs about as much as one percent of a core.
rows.sort(key=lambda g: g["cpu"] + g["rssMb"] / 100, reverse=True)
for g in rows:
    g["cpu"] = round(g["cpu"], 1)
    g["rssMb"] = round(g["rssMb"])
print(json.dumps(rows[:40]))
