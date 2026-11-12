#!/usr/bin/env python3
"""Prints "1" or "0" whenever Caps Lock turns on or off (and once at the start).

Reads the keyboards' Caps Lock LEDs under /sys/class/leds, which the kernel
keeps in step with the lock state. sysfs cannot be watched, so this checks a few
times a second; reading a handful of tiny files costs nothing measurable.
Runs until the shell stops it. Used by Moments.qml.
"""
import glob
import sys
import time


def caps_on():
    for path in glob.glob("/sys/class/leds/*capslock/brightness"):
        try:
            with open(path) as f:
                if int(f.read().strip() or 0) > 0:
                    return True
        except (OSError, ValueError):
            continue
    return False


def main():
    last = None
    while True:
        now = caps_on()
        if now != last:
            print("1" if now else "0", flush=True)
            last = now
        time.sleep(0.2)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
