pragma Singleton

// Downloads.qml — browser downloads running right now. scripts/downloads.py does
// the watching; the island draws the ring and offers the finished file.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var active: []          // [{ name, path, size, total, speed }]
  readonly property bool downloading: active.length > 0
  readonly property string label: active.length > 1 ? active.length + " downloads" : active.length === 1 ? active[0].name : ""

  readonly property real size: active.reduce((sum, d) => sum + d.size, 0)
  readonly property real total: active.every(d => d.total > 0) ? active.reduce((sum, d) => sum + d.total, 0) : 0
  readonly property real speed: active.reduce((sum, d) => sum + d.speed, 0)

  // 0..1, or -1 until the browser has said how big the file is.
  readonly property real progress: downloading && total > 0 ? Math.min(1, size / total) : -1
  readonly property string percent: progress < 0 ? "" : Math.round(progress * 100) + "%"

  readonly property string status: {
    const parts = [];
    if (progress >= 0)
      parts.push(root.bytes(size) + " of " + root.bytes(total));
    else
      parts.push(root.bytes(size));
    if (speed > 0) {
      parts.push(root.bytes(speed) + "/s");
      if (progress >= 0)
        parts.push(root.duration((total - size) / speed) + " left");
    }
    return parts.join(" · ");
  }

  signal finished(string name, string path)

  Process {
    running: true
    command: ["python3", Quickshell.shellPath("scripts/downloads.py")]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.ingest(line)
    }
  }

  function ingest(line) {
    let data;
    try {
      data = JSON.parse(line);
    } catch (e) {
      return;
    }
    if (data.active)
      root.active = data.active;
    if (data.finished)
      root.finished(data.finished.name, data.finished.path);
  }

  function bytes(n) {
    if (n >= 1073741824)
      return (n / 1073741824).toFixed(1) + " GB";
    if (n >= 1048576)
      return (n / 1048576).toFixed(n >= 104857600 ? 0 : 1) + " MB";
    return Math.round(n / 1024) + " KB";
  }

  function duration(seconds) {
    if (seconds < 60)
      return Math.max(1, Math.round(seconds)) + "s";
    if (seconds < 3600)
      return Math.round(seconds / 60) + " min";
    return Math.floor(seconds / 3600) + " h " + Math.round(seconds % 3600 / 60) + " min";
  }

  function openFolder() {
    if (root.active.length > 0)
      Quickshell.execDetached(["xdg-open", root.active[0].path.substring(0, root.active[0].path.lastIndexOf("/"))]);
  }
}
