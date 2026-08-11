// Theme.qml — every colour and measurement the bar uses, in one place.
//
// Colours are driven live by pywal: when the wallpaper changes, pywal rewrites
// ~/.cache/wal/colors.json, the FileView below notices, and the whole bar
// recolours itself without a restart.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // ------------------------------------------------------------- pywal feed
  property var wal: null
  readonly property bool hasWal: wal !== null && wal.colors !== undefined

  FileView {
    path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
    watchChanges: true

    onFileChanged: reload()
    onLoaded: {
      try {
        root.wal = JSON.parse(text());
      } catch (e) {
        root.wal = null;
      }
    }
    onLoadFailed: root.wal = null
  }

  function walColor(key, fallback) {
    return root.hasWal && root.wal.colors[key] ? root.wal.colors[key] : fallback;
  }

  // ------------------------------------------------------------- base tones
  // Fallbacks are Catppuccin Mocha, so the bar still looks deliberate if pywal
  // has never run.
  readonly property color base: hasWal && wal.special ? wal.special.background : "#11111b"
  readonly property color fg: hasWal && wal.special ? wal.special.foreground : "#cdd6f4"
  readonly property color fgDim: walColor("color8", "#6c7086")

  readonly property color c1: walColor("color1", "#f38ba8")
  readonly property color c2: walColor("color2", "#a6e3a1")
  readonly property color c3: walColor("color3", "#f9e2af")
  readonly property color c4: walColor("color4", "#89b4fa")
  readonly property color c5: walColor("color5", "#cba6f7")
  readonly property color c6: walColor("color6", "#94e2d5")

  // Pick the liveliest colour in the palette. pywal often produces six muddy
  // near-greys, so we score on saturation weighted by brightness and then force
  // the winner up to a value that actually reads against the bar.
  readonly property color accentRaw: {
    const ramp = [c1, c2, c3, c4, c5, c6];
    let best = c4;
    let bestScore = -1;
    for (const c of ramp) {
      const score = c.hsvSaturation * (0.4 + c.hsvValue);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  readonly property color accent: Qt.hsva(Math.max(0, accentRaw.hsvHue), Math.min(1.0, accentRaw.hsvSaturation * 1.15), Math.max(0.78, accentRaw.hsvValue), 1.0)

  // ---------------------------------------------------------- derived tones
  readonly property color island: Qt.rgba(base.r, base.g, base.b, 0.82)
  readonly property color raised: Qt.rgba(fg.r, fg.g, fg.b, 0.10)
  readonly property color hover: Qt.rgba(fg.r, fg.g, fg.b, 0.16)
  readonly property color border: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
  readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.20)

  // Status colours stay fixed — a low battery has to read as "low" no matter
  // what the wallpaper is doing.
  readonly property color good: "#a6e3a1"
  readonly property color warn: "#f9e2af"
  readonly property color crit: "#f38ba8"

  // ------------------------------------------------------------- dimensions
  // The display is 1920x1200 at scale 1.5, so only 1280x800 logical pixels.
  // Everything here is deliberately compact.
  readonly property int barHeight: 34
  readonly property int islandHeight: 26
  readonly property int gap: 6          // between islands
  readonly property int margin: 4       // island -> screen edge
  readonly property int padding: 10     // island edge -> content
  readonly property int spacing: 8      // between items inside an island

  readonly property string fontFamily: "FantasqueSansM Nerd Font"
  readonly property int fontSize: 12
  readonly property int iconSize: 14
  readonly property int smallSize: 10

  readonly property int animFast: 140
  readonly property int animSlow: 260
}
