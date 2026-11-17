pragma Singleton

// Stopwatch.qml — a count-up stopwatch with laps, shown by the island (typed
// `timer`). Kept against a wall-clock start rather than ticked, so a busy shell
// can't make it drift; `elapsed` is refreshed ten times a second only while it
// runs. Separate from Tones' focus countdown, which counts down.

import Quickshell
import QtQuick

Singleton {
  id: root

  property bool running: false
  // Milliseconds banked from earlier runs (before the last pause).
  property real banked: 0
  property real startedAt: 0
  property real elapsed: 0
  // Newest first: {n, split, total} in milliseconds.
  property var laps: []

  // Worth a bubble beside the island: running, or paused with time on it.
  readonly property bool active: running || elapsed > 0

  function start() {
    if (root.running)
      return;
    root.startedAt = Date.now();
    root.running = true;
  }

  function pause() {
    if (!root.running)
      return;
    root.banked += Date.now() - root.startedAt;
    root.running = false;
    root.elapsed = root.banked;
  }

  function toggle() {
    root.running ? root.pause() : root.start();
  }

  function lap() {
    if (!root.running)
      return;
    const total = root.banked + Date.now() - root.startedAt;
    const last = root.laps.length > 0 ? root.laps[0].total : 0;
    root.laps = [
      {
        n: root.laps.length + 1,
        split: total - last,
        total: total
      }
    ].concat(root.laps);
  }

  function reset() {
    root.running = false;
    root.banked = 0;
    root.elapsed = 0;
    root.laps = [];
  }

  // 1:02:03.4 / 02:03.45
  function format(ms, centis) {
    const t = Math.floor(ms / 10);
    const c = t % 100;
    const s = Math.floor(t / 100) % 60;
    const m = Math.floor(t / 6000) % 60;
    const h = Math.floor(t / 360000);
    const two = n => (n < 10 ? "0" : "") + n;
    return (h > 0 ? h + ":" : "") + two(m) + ":" + two(s) + (centis ? "." + two(c) : "");
  }

  Timer {
    running: root.running
    interval: 100
    repeat: true
    triggeredOnStart: true
    onTriggered: root.elapsed = root.banked + Date.now() - root.startedAt
  }
}
