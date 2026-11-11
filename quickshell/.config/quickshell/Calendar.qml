pragma Singleton

// Calendar.qml — your Google Calendar, for the island: a countdown before the
// next meeting, an announcement when it starts, and the day's events on the
// Today card. scripts/calendar_feed.py does the fetching and reading, every five
// minutes; the secret link it reads lives outside the dotfiles.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var events: []          // [{ id, title, start, end, allDay, where, link, cal }]
  property string error: ""
  property real now: Date.now()

  readonly property var timed: events.filter(e => !e.allDay)
  readonly property var current: timed.find(e => e.start <= now && now < e.end) ?? null
  readonly property var next: timed.find(e => e.start > now) ?? null
  readonly property int minutesToNext: next ? Math.ceil((next.start - now) / 60000) : -1

  // Days with anything on them, for the dots in the Today card's month grid:
  // { "2026-11-12": [0, 1] }, the calendars (lines of the link file) with
  // something that day. Multi-day events mark every day they cover.
  readonly property var busyDays: {
    const out = {};
    for (const e of root.events) {
      const day = new Date(e.start);
      day.setHours(0, 0, 0, 0);
      const last = e.end - 1;
      for (let i = 0; i < 60 && day.getTime() <= Math.max(last, e.start); i++) {
        const key = root.dayKey(day);
        const cals = out[key] ?? (out[key] = []);
        if (!cals.includes(e.cal ?? 0))
          cals.push(e.cal ?? 0);
        day.setDate(day.getDate() + 1);
      }
    }
    for (const key in out)
      out[key].sort();
    return out;
  }

  function dayKey(date) {
    return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
  }

  // The countdown shows for the last 15 minutes before an event.
  readonly property var soon: next && minutesToNext <= 15 ? next : null

  signal starting(var event)

  // Each event is announced once, within five minutes of its start.
  property var announced: ({})

  onNowChanged: {
    for (const e of root.timed) {
      if (e.start <= root.now && root.now - e.start < 5 * 60000 && !root.announced[e.id]) {
        root.announced[e.id] = true;
        root.starting(e);
      }
    }
  }

  Timer {
    running: true
    repeat: true
    interval: 15000
    onTriggered: root.now = Date.now()
  }

  // ---------------------------------------------------------------- fetching
  function refresh() {
    if (!fetcher.running)
      fetcher.running = true;
  }

  Timer {
    running: true
    repeat: true
    interval: 5 * 60 * 1000
    onTriggered: root.refresh()
  }

  // A moment after startup, so it doesn't compete with everything else.
  Timer {
    running: true
    interval: 10000
    onTriggered: root.refresh()
  }

  Process {
    id: fetcher
    command: ["python3", Quickshell.shellPath("scripts/calendar_feed.py")]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          if (data.events) {
            root.events = data.events;
            root.error = "";
          } else {
            // Offline or similar: keep the last good list.
            root.error = data.error ?? "unknown error";
          }
        } catch (e) {
          root.error = "unreadable reply";
        }
        root.now = Date.now();
      }
    }
  }

  // ----------------------------------------------------------------- helpers
  // Everything on a given day: all-day events first, then by time.
  function forDay(date) {
    const from = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    const to = from + 86400000;
    return root.events.filter(e => e.start < to && e.end > from && (e.allDay || e.start >= from)).sort((a, b) => (b.allDay - a.allDay) || a.start - b.start);
  }

  function clock(ms) {
    return Qt.formatDateTime(new Date(ms), "HH:mm");
  }

  function range(e) {
    return e.allDay ? "All day" : root.clock(e.start) + "–" + root.clock(e.end);
  }

  function length(e) {
    const mins = Math.round((e.end - e.start) / 60000);
    if (mins < 60)
      return mins + " min";
    const h = Math.floor(mins / 60);
    return h + " h" + (mins % 60 ? " " + mins % 60 : "");
  }

  function countdown(e) {
    const mins = Math.max(0, Math.ceil((e.start - root.now) / 60000));
    return mins <= 0 ? "now" : "in " + mins + " min";
  }

  function join(e) {
    if (e && e.link)
      Quickshell.execDetached(["xdg-open", e.link]);
  }
}
