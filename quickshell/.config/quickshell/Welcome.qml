pragma Singleton

// Welcome.qml — a short moment when you sit down.
//
// At login the bar's pills drop in one after another and the island greets you
// with the weather and the day's meetings. After unlocking (the lock bind in
// hyprland.lua calls `welcome away` before hyprlock and `welcome back` after)
// it says what happened while you were gone. A restarted bar plays neither:
// Hyprland's instance signature carries the session's start time, so a login
// is told apart from a restart without waiting for anything.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // Seconds since Hyprland started, from "<hash>_<unix start>_<random>".
  readonly property int sessionAge: {
    const parts = (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").split("_");
    const started = parts.length >= 2 ? Number(parts[1]) : 0;
    return started > 0 ? Math.round(Date.now() / 1000 - started) : 99999;
  }

  // Read once at startup by the bar's pills (Island.qml) and the island.
  readonly property bool entrance: sessionAge < 120

  property string firstName: ""

  Process {
    running: true
    command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
    stdout: StdioCollector {
      onStreamFinished: root.firstName = text.trim().split(/\s+/)[0] || ""
    }
  }

  function greeting() {
    const h = new Date().getHours();
    const part = h >= 5 && h < 12 ? "Good morning" : h < 18 && h >= 12 ? "Good afternoon" : h < 23 && h >= 18 ? "Good evening" : "Up late";
    return root.firstName ? part + ", " + root.firstName : part;
  }

  function glyph() {
    const h = new Date().getHours();
    return h >= 6 && h < 19 ? Icons.sun : Icons.moon;
  }

  function plural(n, word) {
    return n + " " + word + (n === 1 ? "" : "s");
  }

  // ------------------------------------------------------------------ login
  // Waits for the weather and the calendar so the greeting can mention them,
  // but never longer than about nine seconds.
  property int waited: 0

  Timer {
    id: loginWait
    running: root.entrance
    repeat: true
    interval: 500
    onTriggered: {
      root.waited += interval;
      const ready = Weather.ready && Calendar.loaded;
      if (root.waited < 4500 || (!ready && root.waited < 9000))
        return;
      stop();
      root.greet();
    }
  }

  function greet() {
    const parts = [];
    if (Weather.ready)
      parts.push(Weather.tempC + "° " + Weather.place);
    if (Calendar.loaded) {
      const now = Date.now();
      const left = Calendar.forDay(new Date()).filter(e => !e.allDay && e.end > now).length;
      parts.push(left === 0 ? "no meetings today" : root.plural(left, "meeting") + " today");
    }
    Moments.show({
      kind: "welcome",
      glyph: root.glyph(),
      title: root.greeting(),
      sub: parts.join(" · ") || Qt.formatDateTime(new Date(), "dddd, d MMMM"),
      inbox: false
    }, 4200);
    Sounds.play("open");
  }

  // ----------------------------------------------------------- lock, unlock
  property real awaySince: 0
  property int notesAtAway: 0
  property var happened: []

  IpcHandler {
    target: "welcome"

    function away(): void {
      root.awaySince = Date.now();
      root.notesAtAway = Notifications.count;
      root.happened = [];
    }

    function back(): void {
      root.back();
    }
  }

  Connections {
    target: ClaudeCode

    function onFinished(session, failed, seconds) {
      if (root.awaySince > 0 && !root.happened.includes("Claude finished"))
        root.happened = root.happened.concat([failed ? "Claude stopped" : "Claude finished"]);
    }
  }

  Connections {
    target: Downloads

    function onFinished(name, path) {
      if (root.awaySince > 0)
        root.happened = root.happened.concat(["download done"]);
    }
  }

  function back() {
    const away = root.awaySince > 0 ? (Date.now() - root.awaySince) / 60000 : 0;
    const fresh = Math.max(0, Notifications.count - root.notesAtAway);
    const parts = (fresh > 0 ? [root.plural(fresh, "notification")] : []).concat(root.happened.filter((v, i, a) => a.indexOf(v) === i));
    root.awaySince = 0;
    root.happened = [];
    // A quick lock and unlock isn't worth a greeting.
    if (away < 0.5 && parts.length === 0)
      return;
    Moments.show({
      kind: "welcome",
      glyph: root.glyph(),
      title: root.firstName ? "Welcome back, " + root.firstName : "Welcome back",
      sub: parts.length > 0 ? parts.join(" · ") : "Away " + (away < 60 ? Math.max(1, Math.round(away)) + " min" : Math.floor(away / 60) + " h " + Math.round(away % 60) + " min"),
      inbox: fresh > 0
    }, parts.length > 0 ? 6000 : 3000);
    Sounds.play("open");
  }
}
