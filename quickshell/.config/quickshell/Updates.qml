// Updates.qml — pending package updates from the official repos and the AUR.
//
// Uses the same trick as the eww config it replaces: pointing CHECKUPDATES_DB
// at a throwaway path means the check needs no root and never touches the real
// pacman sync database.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // Each entry is { name, from, to }.
  property var repo: []
  property var aur: []

  property bool busy: false
  property bool checkedOnce: false

  readonly property int count: repo.length + aur.length

  // Change this to "paru" if you switch helpers.
  readonly property string aurHelper: "yay"

  Process {
    id: proc

    command: ["sh", "-c", "CHECKUPDATES_DB=$(mktemp -u) checkupdates 2>/dev/null; echo '@@AUR@@'; " + root.aurHelper + " -Qua 2>/dev/null | grep -v '\\[ignored\\]'"]

    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }

    onExited: {
      root.busy = false;
      root.checkedOnce = true;
    }
  }

  function refresh() {
    if (proc.running)
      return;
    root.busy = true;
    proc.running = true;
  }

  function parse(output) {
    const parts = output.split("@@AUR@@");
    root.repo = root.toEntries(parts[0]);
    root.aur = root.toEntries(parts.length > 1 ? parts[1] : "");
  }

  // checkupdates prints "pkgname 1.2.3-1 -> 1.2.4-1".
  // yay -Qua appends how long the package has been out of date, as in
  // "pkgname 1.2.3-1 -> 1.2.4-1 [11d22h]", so the version match must not be
  // anchored to the end of the line.
  function toEntries(block) {
    return block.split("\n").map(l => l.trim()).filter(l => l.length > 0).map(line => {
      const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)(?:\s+\[([^\]]+)\])?/);
      if (m)
        return {
          name: m[1],
          from: m[2],
          to: m[3],
          age: m[4] ?? ""
        };
      return {
        name: line.split(/\s+/)[0],
        from: "",
        to: "",
        age: ""
      };
    });
  }

  // Both checkupdates and the AUR helper hit the network, so don't fire the
  // moment the config loads — a burst of edits would mean a burst of checks.
  Timer {
    running: true
    interval: 5000
    onTriggered: root.refresh()
  }

  Timer {
    running: true
    interval: 10 * 60 * 1000
    repeat: true
    onTriggered: root.refresh()
  }
}
