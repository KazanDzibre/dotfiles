#!/usr/bin/env python3
"""Reports Chromium downloads in progress, as one JSON object per line.

  {"active": [{"name", "path", "size", "total", "speed"}]}   whenever they change
  {"finished": {"name", "path"}}                             when one completes

Chromium writes to "<name>.crdownload" (or "Unconfirmed 123.crdownload" until it
knows the name) and renames it at the end. The file gives the progress; only the
browser's History database knows the final size. That database is locked while
the browser runs, so it's opened immutable, and rows can lag by a few seconds.
"""

import argparse
import glob
import json
import os
import sqlite3
import subprocess
import time
import urllib.parse

SUFFIX = ".crdownload"


def default_folder():
    try:
        out = subprocess.run(["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True, timeout=3)
        if out.stdout.strip():
            return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.expanduser("~/Downloads")


def default_histories():
    found = []
    for browser in ("chromium", "google-chrome", "google-chrome-beta", "BraveSoftware/Brave-Browser", "vivaldi"):
        found += glob.glob(os.path.expanduser(f"~/.config/{browser}/*/History"))
    return found


def read_history(paths):
    """{current_path: (target_path, total_bytes)} for downloads still running."""
    info = {}
    for path in paths:
        try:
            uri = "file:" + urllib.parse.quote(path) + "?immutable=1"
            conn = sqlite3.connect(uri, uri=True, timeout=0.2)
            try:
                rows = conn.execute("SELECT current_path, target_path, total_bytes FROM downloads WHERE state = 0").fetchall()
            finally:
                conn.close()
        except sqlite3.Error:
            # Caught the file mid-write, or an older schema; try again next pass.
            continue
        for current, target, total in rows:
            info[current] = (target, total)
    return info


def scan(folder):
    sizes = {}
    try:
        with os.scandir(folder) as entries:
            for entry in entries:
                if entry.name.endswith(SUFFIX) and not entry.name.startswith("."):
                    try:
                        sizes[entry.path] = entry.stat().st_size
                    except OSError:
                        pass
    except OSError:
        pass
    return sizes


def newest_recent(folder, seconds=5):
    """The file that just appeared, for a download that never got a real name."""
    best = None
    best_time = time.time() - seconds
    try:
        with os.scandir(folder) as entries:
            for entry in entries:
                if entry.name.startswith(".") or entry.name.endswith(SUFFIX) or not entry.is_file():
                    continue
                stamp = entry.stat().st_mtime
                if stamp > best_time:
                    best, best_time = entry.path, stamp
    except OSError:
        pass
    return best


def display_name(path, info):
    target = info.get(path, ("", 0))[0]
    if target:
        return os.path.basename(target)
    name = os.path.basename(path)[: -len(SUFFIX)]
    return "Download" if name.startswith("Unconfirmed ") else name


def where_it_went(path, info, folder, others_appeared):
    """Where a vanished .crdownload ended up, or None if it was cancelled."""
    target = info.get(path, ("", 0))[0]
    if target and os.path.exists(target):
        return target
    plain = path[: -len(SUFFIX)]
    if os.path.exists(plain):
        return plain
    if os.path.basename(path).startswith("Unconfirmed ") and not others_appeared:
        return newest_recent(folder)
    return None


def emit(payload):
    print(json.dumps(payload), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--folder", default=None)
    parser.add_argument("--history", action="append", default=None)
    parser.add_argument("--interval", type=float, default=1.0)
    args = parser.parse_args()

    folder = args.folder or default_folder()
    previous = {}
    info = {}
    speeds = {}
    last_lines = None
    last_time = time.monotonic()
    tick = 0

    while True:
        time.sleep(args.interval)
        tick += 1
        now = time.monotonic()
        elapsed = max(0.001, now - last_time)
        last_time = now
        sizes = scan(folder)

        if sizes and tick % 2 == 0:
            histories = args.history if args.history is not None else default_histories()
            info.update(read_history(histories))

        appeared = set(sizes) - set(previous)
        for path in set(previous) - set(sizes):
            final = where_it_went(path, info, folder, bool(appeared))
            if final:
                emit({"finished": {"name": os.path.basename(final), "path": final}})
            info.pop(path, None)
            speeds.pop(path, None)

        active = []
        for path, size in sorted(sizes.items()):
            if path in previous:
                rate = max(0, size - previous[path]) / elapsed
                speeds[path] = speeds.get(path, rate) * 0.6 + rate * 0.4
            active.append({
                "name": display_name(path, info),
                "path": path,
                "size": size,
                "total": max(0, info.get(path, ("", 0))[1] or 0),
                "speed": round(speeds.get(path, 0)),
            })

        if active != last_lines:
            emit({"active": active})
            last_lines = active
        previous = sizes


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
