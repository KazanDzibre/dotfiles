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
    // After the text, a group separator when the copying app says this is
    // sensitive (password managers set this hint), then the record separator.
    command: ["wl-paste", "--type", "text", "--watch", "sh", "-c", "cat; wl-paste --list-types 2>/dev/null | grep -qx x-kde-passwordManagerHint && printf '\\035'; printf '\\036'"]

    stdout: SplitParser {
      splitMarker: "\u001E"
      onRead: data => root.arrive(data)
    }
  }

  // Fired for every copy made anywhere except from this panel. `sensitive`
  // copies carry no text at all: the island is told something secret was
  // copied and never gets to see it, and it is not kept in the history.
  signal arrived(string text, bool sensitive)

  property string lastWritten: ""
  property double lastWrittenAt: 0

  function arrive(data) {
    const sensitive = data.endsWith("\u001D");
    const text = sensitive ? "" : data;
    if (sensitive) {
      root.arrived("", true);
      return;
    }
    root.record(text);
    // Our own wl-copy shows up on the watcher too; that was already announced.
    if (text === root.lastWritten && Date.now() - root.lastWrittenAt < 1500)
      return;
    if (text.trim().length > 0)
      root.arrived(text, false);
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

  // Fired when something is copied from the clipboard panel; the island shows it.
  signal copied(string text)

  function copy(text) {
    root.lastWritten = text;
    root.lastWrittenAt = Date.now();
    root.copied(text);
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

  // What a clipping is, for the history list: a colour, a link, a file path or
  // plain text. The same rules the island applies to a fresh copy (Moments.qml),
  // kept to the simple single-line shapes.
  //   color  { type, color }
  //   link   { type, host, rest }
  //   file   { type, name, folder }
  //   text   { type }
  function describe(text) {
    const t = text.trim();
    if (t.indexOf("\n") >= 0)
      return {
        type: "text"
      };
    let m = t.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
    if (m)
      return {
        type: "color",
        color: "#" + m[1]
      };
    m = t.match(/^rgba?\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})/i);
    if (m && m[1] <= 255 && m[2] <= 255 && m[3] <= 255)
      return {
        type: "color",
        color: "#" + [m[1], m[2], m[3]].map(n => ("0" + Number(n).toString(16)).slice(-2)).join("")
      };
    m = t.match(/^https?:\/\/([^\/?#\s]+)([^\s]*)$/i);
    if (m)
      return {
        type: "link",
        host: m[1].replace(/^www\./, ""),
        rest: m[2]
      };
    if (/^(~\/|\/)[^\n]{1,300}$/.test(t) && t.length > 2) {
      const slash = t.lastIndexOf("/");
      return {
        type: "file",
        name: t.substring(slash + 1) || t,
        folder: slash > 0 ? t.substring(0, slash) : "/"
      };
    }
    return {
      type: "text"
    };
  }

  function lineCount(text) {
    return text.split("\n").length;
  }
}
