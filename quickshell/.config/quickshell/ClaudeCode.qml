pragma Singleton

// ClaudeCode.qml — what Claude Code sessions on this machine are up to.
//
// scripts/claude-hook.py reports each session's state over IPC. The island shows
// the one that matters most: one waiting on you first, otherwise the busiest.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  property var sessions: ({})

  readonly property var list: Object.values(sessions)
  readonly property var waiting: list.find(s => s.state === "waiting") ?? null
  readonly property var working: list.filter(s => s.state === "working").sort((a, b) => b.stamp - a.stamp)[0] ?? null
  readonly property var current: waiting ?? working

  signal finished(var session, bool failed, int seconds)

  IpcHandler {
    target: "claude"

    function event(id: string, kind: string, detail: string, project: string, window: string, stamp: int): void {
      root.update(id, kind, detail === "_" ? "" : detail, project === "_" ? "" : project, window === "_" ? "" : window, stamp);
    }
  }

  function update(id, kind, detail, project, window, stamp) {
    const old = root.sessions[id];
    // Hooks run in the background, so a late one can arrive after a newer one.
    if (old && stamp < old.stamp)
      return;

    const next = Object.assign({}, root.sessions);
    if (kind === "end") {
      delete next[id];
      root.sessions = next;
      return;
    }

    const session = Object.assign({
      id: id,
      since: Date.now(),
      window: "",
      project: project
    }, old ?? {}, {
      stamp: stamp,
      seen: Date.now(),
      detail: detail
    });
    if (window)
      session.window = window;
    if (kind === "start") {
      session.since = Date.now();
      session.steps = [];
    }
    // The last few things it did, for the island's Claude card.
    if (detail && kind !== "done" && kind !== "failed") {
      const steps = (session.steps ?? []).filter(s => s !== detail);
      session.steps = steps.concat([detail]).slice(-4);
    }

    if (kind === "done" || kind === "failed") {
      const wasBusy = old && old.state !== "idle";
      session.state = "idle";
      next[id] = session;
      root.sessions = next;
      if (wasBusy)
        root.finished(session, kind === "failed", Math.round((Date.now() - session.since) / 1000));
      return;
    }

    session.state = kind === "waiting" ? "waiting" : "working";
    next[id] = session;
    root.sessions = next;
  }

  function focus(address) {
    if (!address)
      return;
    const wanted = address.replace(/^0x/, "");
    Hyprland.refreshToplevels();
    const match = Array.from(Hyprland.toplevels.values).find(t => String(t.address).replace(/^0x/, "") === wanted);
    if (match && match.wayland)
      match.wayland.activate();
  }

  function formatElapsed(seconds) {
    if (seconds < 60)
      return seconds + "s";
    const m = Math.floor(seconds / 60);
    return m + "m " + (seconds % 60 < 10 ? "0" : "") + (seconds % 60) + "s";
  }

  // A session that crashed never reports back; don't show it working forever.
  Timer {
    running: true
    repeat: true
    interval: 60000
    onTriggered: {
      const next = Object.assign({}, root.sessions);
      let changed = false;
      for (const id in next) {
        if (next[id].state === "working" && Date.now() - next[id].seen > 15 * 60000) {
          next[id] = Object.assign({}, next[id], {
            state: "idle"
          });
          changed = true;
        }
      }
      if (changed)
        root.sessions = next;
    }
  }
}
