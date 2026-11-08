pragma Singleton

// Lyrics.qml — time-synced lyrics for the current track, from lrclib.net.
//
// Looked up once per song and remembered. Tracks with no synced lyrics simply
// don't show any.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var lines: []           // [{ time, text }], in order
  property var cache: ({})
  readonly property bool available: lines.length > 0

  readonly property string track: Media.hasPlayer && Media.title ? Media.artist + "\u0001" + Media.title : ""

  // The line being sung right now, or -1 before the first.
  readonly property int currentIndex: {
    const p = Media.position;
    let found = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time > p)
        break;
      found = i;
    }
    return found;
  }

  onTrackChanged: {
    root.lines = [];
    if (root.track.length === 0)
      return;
    if (root.cache[root.track] !== undefined) {
      root.lines = root.cache[root.track];
      return;
    }
    fetcher.track = root.track;
    fetcher.exec(["curl", "-sfG", "--max-time", "10", "https://lrclib.net/api/get", "--data-urlencode", "artist_name=" + Media.artist, "--data-urlencode", "track_name=" + Media.title]);
  }

  function parse(lrc) {
    const out = [];
    for (const line of String(lrc ?? "").split("\n")) {
      const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
      if (m)
        out.push({
          time: Number(m[1]) * 60 + Number(m[2]),
          text: m[3].trim() || "♪"
        });
    }
    return out;
  }

  Process {
    id: fetcher

    property string track: ""

    stdout: StdioCollector {
      onStreamFinished: {
        let parsed = [];
        try {
          parsed = root.parse(JSON.parse(text).syncedLyrics);
        } catch (e) {
          // Not found or offline: this song just has no lyrics.
        }
        const next = Object.assign({}, root.cache);
        next[fetcher.track] = parsed;
        root.cache = next;
        if (fetcher.track === root.track)
          root.lines = parsed;
      }
    }
  }
}
