pragma Singleton

// Recorder.qml — screen recording with wf-recorder (and slurp for a region).
//
// Files land in ~/Videos/Recordings. wf-recorder finishes the file cleanly on
// SIGINT, so stopping always goes through that. Both tools are optional: without
// them, the island says what to install.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  readonly property string folder: Quickshell.env("HOME") + "/Videos/Recordings"

  property bool recording: false
  property real startedAt: 0
  property int seconds: 0
  property string file: ""

  signal finished(string path, string thumbnail)
  signal missing(string tool)

  IpcHandler {
    target: "recorder"

    function toggle(): void {
      root.toggle(false);
    }

    function region(): void {
      root.toggle(true);
    }
  }

  function toggle(pickRegion) {
    if (root.recording)
      root.stop();
    else
      root.start(pickRegion);
  }

  function start(pickRegion) {
    if (root.recording || starter.running)
      return;
    root.file = root.folder + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
    const output = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    // exec so that SIGINT reaches wf-recorder itself. A cancelled slurp exits
    // non-zero and nothing starts.
    const script = 'command -v wf-recorder >/dev/null || { echo MISSING wf-recorder; exit 127; }\n' +
      'mkdir -p "$(dirname "$1")"\n' +
      'if [ "$3" = region ]; then\n' +
      '  command -v slurp >/dev/null || { echo MISSING slurp; exit 127; }\n' +
      '  area=$(slurp) || exit 130\n' +
      '  echo STARTED\n' +
      '  exec wf-recorder -g "$area" -f "$1" -y\n' +
      'fi\n' +
      'echo STARTED\n' +
      'exec wf-recorder -o "$2" -f "$1" -y\n';
    starter.command = ["sh", "-c", script, "sh", root.file, output, pickRegion ? "region" : "full"];
    starter.running = true;
  }

  function stop() {
    if (starter.running)
      starter.signal(2);
  }

  Process {
    id: starter

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        if (line.startsWith("MISSING ")) {
          root.missing(line.substring(8));
        } else if (line === "STARTED") {
          root.startedAt = Date.now();
          root.seconds = 0;
          root.recording = true;
        }
      }
    }

    onExited: {
      const was = root.recording;
      root.recording = false;
      if (was)
        thumbnailer.exec(["sh", "-c", 'out="$HOME/.cache/quickshell-recording-thumb.png"; ffmpegthumbnailer -i "$1" -o "$out" -s 320 -t 10 >/dev/null 2>&1 && printf %s "$out"', "sh", root.file]);
    }
  }

  Process {
    id: thumbnailer
    stdout: StdioCollector {
      onStreamFinished: root.finished(root.file, text.trim())
    }
  }

  Timer {
    running: root.recording
    repeat: true
    interval: 500
    onTriggered: root.seconds = Math.floor((Date.now() - root.startedAt) / 1000)
  }

  function formatTime(s) {
    const m = Math.floor(s / 60);
    return (m < 10 ? "0" : "") + m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
  }
}
