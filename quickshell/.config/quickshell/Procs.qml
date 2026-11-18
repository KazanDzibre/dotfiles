pragma Singleton

// Procs.qml — your heaviest programs, for the island's `kill` search.
// scripts/procs.py samples /proc and groups by name (Chromium is one row, not
// forty). Refreshed while the search is looking at it, not in the background.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // {name, pids, count, cpu, rssMb}, heaviest first.
  property var list: []
  // name -> when it was asked to quit, so a second Enter can force it.
  property var asked: ({})
  property real watchUntil: 0

  // Called as the search text changes; keeps the list fresh for a few seconds.
  function watch() {
    root.watchUntil = Date.now() + 6000;
    root.refresh();
  }

  function refresh() {
    if (!sampler.running)
      sampler.running = true;
  }

  function forcing(name) {
    return Date.now() - (root.asked[name] ?? 0) < 30000;
  }

  // Quit politely first; asked again within half a minute, force it.
  function quit(item) {
    const force = root.forcing(item.name);
    Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(item.pids.map(String)));
    const next = Object.assign({}, root.asked);
    next[item.name] = force ? 0 : Date.now();
    root.asked = next;
    Moments.toast(Icons.stop, item.name, force ? "KILLED" : "QUIT", false, 1800);
    afterKill.restart();
  }

  Timer {
    id: afterKill
    interval: 900
    onTriggered: root.refresh()
  }

  Timer {
    running: Date.now() < root.watchUntil
    interval: 2000
    repeat: true
    onTriggered: {
      if (Date.now() < root.watchUntil)
        root.refresh();
    }
  }

  Process {
    id: sampler
    command: ["python3", Quickshell.shellPath("scripts/procs.py")]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.list = JSON.parse(text);
        } catch (e) {}
      }
    }
  }
}
