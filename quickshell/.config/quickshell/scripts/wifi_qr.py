#!/usr/bin/env python3
"""A QR code that joins a Wi-Fi network, for the island's `wifiqr` view.

Usage: wifi_qr.py [ssid]     (no ssid: the network you are connected to)
Finds the saved connection for that SSID, reads its password from
NetworkManager (nmcli -s), and has qrencode draw the standard
WIFI:T:WPA;S:<ssid>;P:<password>;; code into a PNG under XDG_RUNTIME_DIR.

The password goes to qrencode on stdin, never on a command line, and is never
printed: stdout is one JSON line, {"path": ..., "ssid": ...} or {"error": ...}. The caller
deletes the PNG as soon as it has loaded it.
"""
import json
import os
import shutil
import subprocess
import sys


def nmcli(*args):
    return subprocess.run(["nmcli", *args], capture_output=True, text=True, timeout=10).stdout


def escape(text):
    # The backslash goes first, so the ones added for the others are not doubled.
    for ch in ("\\", ";", ",", ":", '"'):
        text = text.replace(ch, "\\" + ch)
    return text


def active_ssid():
    for line in nmcli("-t", "-f", "ACTIVE,SSID", "device", "wifi").splitlines():
        if line.startswith("yes:"):
            return line[4:].replace("\\:", ":")
    return ""


def connection_for(ssid):
    for line in nmcli("-t", "-f", "NAME,TYPE", "connection", "show").splitlines():
        # Names can hold escaped colons; the type is always the last field.
        name, _, kind = line.rpartition(":")
        if kind != "802-11-wireless":
            continue
        name = name.replace("\\:", ":")
        if nmcli("-g", "802-11-wireless.ssid", "connection", "show", name).strip() == ssid:
            return name
    return None


def payload(ssid, name):
    fields = nmcli("-s", "-g", "802-11-wireless-security.key-mgmt,802-11-wireless-security.psk", "connection", "show", name).split("\n")
    mgmt = fields[0].strip() if fields else ""
    psk = fields[1] if len(fields) > 1 else ""
    if mgmt == "":
        return f"WIFI:T:nopass;S:{escape(ssid)};;"
    if mgmt not in ("wpa-psk", "sae"):
        raise ValueError("Only password networks can be shared")
    if not psk:
        raise ValueError("No saved password for this network")
    kind = "SAE" if mgmt == "sae" else "WPA"
    return f"WIFI:T:{kind};S:{escape(ssid)};P:{escape(psk)};;"


def main():
    ssid = " ".join(sys.argv[1:])
    try:
        if not shutil.which("qrencode"):
            raise ValueError("Install qrencode to share networks")
        ssid = ssid or active_ssid()
        if not ssid:
            raise ValueError("You're not on a Wi-Fi network")
        name = connection_for(ssid)
        if not name:
            raise ValueError("This network isn't saved")
        text = payload(ssid, name)
        out = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "qs-wifi-qr.png")
        subprocess.run(["qrencode", "-t", "PNG", "-s", "10", "-m", "2", "-o", out], input=text, text=True, check=True, timeout=10)
        os.chmod(out, 0o600)
        print(json.dumps({"path": out, "ssid": ssid}))
    except Exception as exc:
        print(json.dumps({"error": str(exc) if isinstance(exc, ValueError) else "Couldn't make the code"}))


if __name__ == "__main__":
    main()
