// Clipboard.qml — clipboard history.
//
// Quickshell's own `Quickshell.clipboardText` never updates on this compositor
// (it reads back empty no matter what is copied), so the history is fed by
// `wl-paste --watch` instead. That also means no cliphist dependency: wl-clipboard
// is already installed.
//
// Entries are separated by an ASCII record separator rather than newlines, so
// multi-line clippings survive intact.
//
// Deliberately in-memory only. A clipboard history on disk is a file full of
// whatever you have ever copied, passwords included; this one dies with the
// shell.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property int maxEntries: 60

  property var entries: []
  readonly property int count: entries.length

  Process {
    running: true
    command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", "cat; printf '\\036'"]

    stdout: SplitParser {
      splitMarker: "\u001E"
      onRead: data => root.record(data)
    }
  }

  function record(text) {
    if (!text || text.trim().length === 0)
      return;

    // Re-copying something already in the list moves it to the top rather than
    // duplicating it — which is also what happens when you paste from here.
    const next = root.entries.filter(e => e !== text);
    next.unshift(text);
    while (next.length > root.maxEntries)
      next.pop();
    root.entries = next;
  }

  Process {
    id: writer
  }

  function copy(text) {
    writer.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text];
    writer.startDetached();
    root.record(text);
  }

  function remove(text) {
    root.entries = root.entries.filter(e => e !== text);
  }

  function clear() {
    root.entries = [];
  }

  // Single-line preview for the list.
  function preview(text) {
    const flattened = text.replace(/\s+/g, " ").trim();
    return flattened.length > 120 ? flattened.substring(0, 120) + "…" : flattened;
  }

  function lineCount(text) {
    return text.split("\n").length;
  }
}
