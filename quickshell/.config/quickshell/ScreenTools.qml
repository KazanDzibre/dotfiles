pragma Singleton

// ScreenTools.qml — `pick` from the island search: hyprpicker's magnifier, and
// the colour you click is copied. The island's clipboard peek (Moments.qml)
// then shows it as the colour card with its other formats; nothing here draws.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  signal missing(string tool)

  // A beat first, so the search has folded away before the screen is read.
  function pick() {
    pickDelay.restart();
  }

  Timer {
    id: pickDelay
    interval: 280
    onTriggered: worker.exec(["sh", "-c", root.pickScript])
  }

  // Esc just ends it, copying nothing. wl-copy stays behind to serve the
  // clipboard, so it must not hold on to this process's output, or the result
  // is never read and the next run's message never arrives.
  readonly property string pickScript: [
    'command -v hyprpicker >/dev/null || { echo "missing hyprpicker"; exit; }',
    'c=$(hyprpicker -f hex 2>/dev/null | tr -d "[:space:]")',
    '[ -n "$c" ] && printf "%s" "$c" | wl-copy >/dev/null 2>&1'
  ].join("\n")

  Process {
    id: worker

    stdout: StdioCollector {
      onStreamFinished: {
        const out = text.trim();
        if (out.startsWith("missing "))
          root.missing(out.substring(8));
      }
    }
  }
}
