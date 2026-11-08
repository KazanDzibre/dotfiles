pragma Singleton

// Privacy.qml — which apps are using the microphone or the camera right now.
//
// Microphone comes from PipeWire's Pulse layer: `pactl subscribe` says when a
// recording stream starts or stops, so nothing is polled. Streams that only
// listen to a speaker's monitor (cava, our analyser) or draw a level meter
// (pavucontrol's "Peak detect") aren't recording you, so they don't count.
//
// The camera has no such event feed, so its devices are checked every few
// seconds for anything holding them open. An app that reaches the camera some
// other way won't show up.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var micApps: []
  property var camApps: []
  readonly property bool micInUse: micApps.length > 0
  readonly property bool camInUse: camApps.length > 0

  // ---------------------------------------------------------------- mic
  Process {
    id: subscribe
    running: true
    command: ["pactl", "subscribe"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        if (line.includes("source-output"))
          listSoon.restart();
      }
    }

    // PipeWire restarted, most likely. Reattach once it's back.
    onExited: reattach.restart()
  }

  Timer {
    id: reattach
    interval: 3000
    onTriggered: {
      subscribe.running = true;
      listSoon.restart();
    }
  }

  // Also runs once at startup, for anything already recording.
  Timer {
    id: listSoon
    running: true
    interval: 150
    onTriggered: lister.running = true
  }

  Process {
    id: lister
    command: ["sh", "-c", "pactl -f json list source-outputs; echo; pactl -f json list sources"]

    stdout: StdioCollector {
      onStreamFinished: {
        let streams = [];
        let sources = [];
        try {
          const parts = text.trim().split("\n").filter(l => l.trim().length > 0);
          streams = JSON.parse(parts[0]);
          sources = JSON.parse(parts[1]);
        } catch (e) {
          return;
        }
        const monitors = new Set(sources.filter(s => s.monitor_source || String(s.name).endsWith(".monitor")).map(s => s.index));
        const names = new Set();
        for (const s of streams) {
          const p = s.properties ?? {};
          if (s.corked || monitors.has(s.source) || p["media.name"] === "Peak detect")
            continue;
          names.add(p["application.name"] || p["application.process.binary"] || "An app");
        }
        root.micApps = Array.from(names);
      }
    }
  }

  // ------------------------------------------------------------- camera
  Timer {
    running: true
    repeat: true
    triggeredOnStart: true
    interval: 4000
    onTriggered: camCheck.running = true
  }

  Process {
    id: camCheck
    command: ["sh", "-c", "fuser /dev/video* 2>/dev/null | tr -s ' ' '\\n' | grep . | sort -u | xargs -r ps -o comm= -p | sort -u"]

    stdout: StdioCollector {
      onStreamFinished: {
        const names = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
        if (JSON.stringify(names) !== JSON.stringify(root.camApps))
          root.camApps = names;
      }
    }
  }
}
