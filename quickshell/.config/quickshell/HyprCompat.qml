// HyprCompat.qml — one place that knows which dispatch syntax Hyprland speaks.
//
// Hyprland 0.57 parses `hyprctl dispatch` as Lua and rejects the bare-word form;
// Ubuntu 26.04 ships 0.53, which only understands the bare words. The shell is
// shared between both machines, so each call site hands over both spellings and
// this picks one. Reading `hyprctl version` once is cheaper and more honest than
// trying a dispatch and parsing its failure. Calls made before the answer is in
// are held and replayed, so an early click is delayed rather than lost.
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // Unknown until the version probe returns.
  property bool known: false
  property bool lua: false
  property var pending: []

  function dispatch(legacy, luaForm) {
    if (!root.known) {
      root.pending = root.pending.concat([[legacy, luaForm]]);
      return;
    }
    Hyprland.dispatch(root.lua ? luaForm : legacy);
  }

  Process {
    running: true
    command: ["hyprctl", "version", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        let minor = 0;
        try {
          minor = parseInt(JSON.parse(text).version.split(".")[1]);
        } catch (e) {}
        root.lua = minor >= 57;
        root.known = true;
        const queued = root.pending;
        root.pending = [];
        for (const c of queued)
          root.dispatch(c[0], c[1]);
      }
    }
  }
}
