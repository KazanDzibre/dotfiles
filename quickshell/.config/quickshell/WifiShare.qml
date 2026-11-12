pragma Singleton

// WifiShare.qml — the QR code that joins the Wi-Fi network you are on, shown by
// the island (typed `wifiqr`). scripts/wifi_qr.py draws the PNG; it holds the
// password, so the island calls shred() the moment the image has loaded and the
// file is gone before anyone could pick it up.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string ssid: ""
  property string path: ""
  property string error: ""
  property bool busy: false

  function start() {
    if (maker.running)
      return;
    root.ssid = "";
    root.path = "";
    root.error = "";
    root.busy = true;
    maker.running = true;
  }

  // Drops the code, and the file if it is still there.
  function clear() {
    root.shred();
    root.path = "";
    root.ssid = "";
    root.error = "";
  }

  function shred() {
    if (root.path.length > 0) {
      eraser.command = ["rm", "-f", root.path];
      eraser.running = true;
    }
  }

  Process {
    id: maker
    command: ["python3", Quickshell.shellPath("scripts/wifi_qr.py")]

    stdout: StdioCollector {
      onStreamFinished: {
        root.busy = false;
        try {
          const parsed = JSON.parse(text);
          root.error = parsed.error ?? "";
          root.ssid = parsed.ssid ?? "";
          root.path = parsed.path ?? "";
        } catch (e) {
          root.error = "Couldn't make the code";
        }
      }
    }
  }

  Process {
    id: eraser
  }
}
