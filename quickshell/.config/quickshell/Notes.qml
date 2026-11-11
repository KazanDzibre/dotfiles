pragma Singleton

// Notes.qml — quick notes typed into the island search (`note …`).
//
// They live in one Markdown checklist outside the dotfiles, so they can also be
// edited by hand; changes made there show up here straight away:
//
//   - [ ] call the bank tomorrow
//   - [ ] stretch @ 2026-11-11 15:00      <- a reminder
//   - [x] renew the parking permit
//
// `note at 15:00 stretch` sets a reminder for the next 15:00. When it fires the
// time is dropped from the line, so it only goes off once.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string path: Quickshell.env("HOME") + "/.local/share/quickshell/notes.md"

  property var items: []          // [{ text, done, at (ms, 0 = none) }]
  readonly property int open: items.filter(n => !n.done).length

  signal reminder(string text, string time)
  signal saved(string text)

  // ------------------------------------------------------------------- file
  FileView {
    id: file
    path: root.path
    watchChanges: true

    onLoaded: root.items = root.parse(text())
    onFileChanged: reload()
    // First run: create it, so this doesn't warn on every start. Deferred, as
    // in Spotlight.qml: a write from inside the failed read gets dropped.
    onLoadFailed: {
      root.items = [];
      Qt.callLater(() => file.setText(""));
    }
  }

  // The folder may not exist yet on a fresh machine.
  Process {
    running: true
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/share/quickshell"]
  }

  function parse(text) {
    const out = [];
    for (const line of text.split("\n")) {
      const m = line.match(/^\s*[-*] \[([ xX])\] (.*?)(?:\s+@ (\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d))?\s*$/);
      if (!m || !m[2])
        continue;
      out.push({
        text: m[2],
        done: m[1] !== " ",
        at: m[3] ? new Date(+m[3], +m[4] - 1, +m[5], +m[6], +m[7]).getTime() : 0
      });
    }
    return out;
  }

  function stamp(ms) {
    return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd HH:mm");
  }

  function write(list) {
    root.items = list;
    file.setText(list.map(n => "- [" + (n.done ? "x" : " ") + "] " + n.text + (n.at ? " @ " + root.stamp(n.at) : "")).join("\n") + "\n");
  }

  // ---------------------------------------------------------------- editing
  // "at 15:00 stretch", "at 9 stretch" or "at 9:30 stretch": the next time it
  // is that o'clock. Anything else is the note as typed.
  function add(raw) {
    let text = raw.trim();
    let at = 0;
    const m = text.match(/^at (\d{1,2})(?:[:.](\d\d))?\s+(.+)$/i);
    if (m && +m[1] < 24 && (!m[2] || +m[2] < 60)) {
      const now = new Date();
      const when = new Date(now.getFullYear(), now.getMonth(), now.getDate(), +m[1], m[2] ? +m[2] : 0);
      if (when.getTime() <= now.getTime())
        when.setDate(when.getDate() + 1);
      at = when.getTime();
      text = m[3].trim();
    }
    if (!text)
      return;
    root.write([{
        text: text,
        done: false,
        at: at
      }].concat(root.items));
    root.saved(text);
  }

  function toggle(index) {
    root.write(root.items.map((n, i) => i === index ? Object.assign({}, n, {
          done: !n.done
        }) : n));
  }

  function remove(index) {
    root.write(root.items.filter((n, i) => i !== index));
  }

  function clearDone() {
    root.write(root.items.filter(n => !n.done));
  }

  // In Neovim, in whichever terminal exists (the same order as the search uses).
  function edit() {
    Quickshell.execDetached(["sh", "-c", 'if command -v alacritty >/dev/null; then exec alacritty -e nvim "$1"; elif command -v kitty >/dev/null; then exec kitty nvim "$1"; elif command -v ptyxis >/dev/null; then exec ptyxis -s -x "nvim $1"; else exec foot nvim "$1"; fi', "sh", root.path]);
  }

  function timeLabel(ms) {
    if (!ms)
      return "";
    const d = new Date(ms);
    const today = new Date();
    return d.toDateString() === today.toDateString() ? Qt.formatDateTime(d, "HH:mm") : Qt.formatDateTime(d, "ddd HH:mm");
  }

  // -------------------------------------------------------------- reminders
  Timer {
    running: root.items.some(n => n.at > 0 && !n.done)
    repeat: true
    // Not on start: the island ignores everything for its first few seconds,
    // and a reminder fired then would be lost.
    interval: 15000
    onTriggered: {
      const now = Date.now();
      const due = root.items.filter(n => n.at > 0 && !n.done && n.at <= now);
      if (due.length === 0)
        return;
      for (const n of due)
        root.reminder(n.text, Qt.formatDateTime(new Date(n.at), "HH:mm"));
      root.write(root.items.map(n => due.includes(n) ? Object.assign({}, n, {
            at: 0
          }) : n));
    }
  }
}
