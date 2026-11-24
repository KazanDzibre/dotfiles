// Theme.qml — every colour and measurement the bar uses, in one place.
//
// Colours are driven live by pywal: when the wallpaper changes, pywal rewrites
// ~/.cache/wal/colors.json, the FileView below notices, and the whole bar
// recolours itself without a restart.
//
// There are two modes, and *both* are derived from that same pywal palette
// rather than from a hardcoded light scheme. pywal only ever produces a dark
// palette, so light mode reuses its hues and rebuilds the lightness: the
// wallpaper's foreground becomes a near-white ground, its background becomes
// the ink, and the accent is darkened until it reads on a pale surface.
// Everything else in the file is expressed relative to base/fg/accent, so the
// two modes fall out of four definitions.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // ------------------------------------------------------------------- mode
  property string mode: "dark"
  readonly property bool isLight: mode === "light"

  function toggleMode() {
    root.mode = root.isLight ? "dark" : "light";
    modeFile.setText(root.mode);
  }

  // Remembered across restarts.
  FileView {
    id: modeFile
    path: Quickshell.cachePath("theme-mode")

    onLoaded: {
      const saved = text().trim();
      if (saved === "light" || saved === "dark")
        root.mode = saved;
    }
    // First run: create it with the default, so this doesn't warn every start.
    // Deferred, because writing from inside the failed read's own handler makes
    // FileView complain about a dropped operation.
    onLoadFailed: Qt.callLater(() => modeFile.setText(root.mode))
  }

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

  // ------------------------------------------------------- raw wallpaper tones
  // Fallbacks are Catppuccin Mocha, so the bar still looks deliberate if pywal
  // has never run.
  property color walBg: hasWal && wal.special ? wal.special.background : "#11111b"
  property color walFg: hasWal && wal.special ? wal.special.foreground : "#cdd6f4"
  property color walDim: walColor("color8", "#6c7086")

  property color c1: walColor("color1", "#f38ba8")
  property color c2: walColor("color2", "#a6e3a1")
  property color c3: walColor("color3", "#f9e2af")
  property color c4: walColor("color4", "#89b4fa")
  property color c5: walColor("color5", "#cba6f7")
  property color c6: walColor("color6", "#94e2d5")

  // A new wallpaper changes these; everything the shell derives from them
  // (accent, text, glass, highlights) follows, so the palette glides to the
  // new colours instead of snapping.
  Behavior on walBg {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on walFg {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on walDim {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c1 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c2 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c3 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c4 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c5 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on c6 {
    ColorAnimation {
      duration: root.paletteMs
      easing.type: Easing.InOutQuad
    }
  }

  readonly property int paletteMs: motionAmbient

  // Pick the liveliest colour in the palette. pywal often produces six muddy
  // near-greys, so we score on saturation weighted by brightness.
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

  // A fully desaturated colour reports hue -1, which would break Qt.hsva.
  readonly property real accentHue: Math.max(0, accentRaw.hsvHue)
  readonly property real bgHue: Math.max(0, walBg.hslHue)
  readonly property real fgHue: Math.max(0, walFg.hslHue)

  // ----------------------------------------------------------- the four roots
  readonly property color base: isLight ? Qt.hsla(fgHue, Math.min(0.30, walFg.hslSaturation), 0.955, 1.0) : walBg

  readonly property color fg: isLight ? Qt.hsla(bgHue, Math.min(0.45, walBg.hslSaturation + 0.12), 0.12, 1.0) : Qt.tint(walFg, Qt.rgba(1, 1, 1, 0.45))

  readonly property color fgDim: isLight ? Qt.hsla(bgHue, Math.min(0.22, walBg.hslSaturation), 0.36, 1.0) : Qt.tint(walFg, Qt.rgba(1, 1, 1, 0.35))

  // Dark mode forces the accent bright enough to read on near-black; light mode
  // forces it dark enough to read on near-white. Same hue either way.
  readonly property color accent: isLight ? Qt.hsva(accentHue, Math.max(0.45, Math.min(1.0, accentRaw.hsvSaturation * 1.25)), Math.min(0.60, Math.max(0.34, accentRaw.hsvValue)), 1.0) : Qt.hsva(accentHue, Math.min(1.0, accentRaw.hsvSaturation * 1.15), Math.max(0.78, accentRaw.hsvValue), 1.0)

  // ---------------------------------------------------------- derived tones
  // All relative to the four above, so they follow the mode automatically.
  // The pills and panels are liquid glass: a thin tint of the base over
  // Hyprland's blur of the wallpaper, with GlassSheen's light on top. (The
  // Dynamic Island doesn't use this; it stays solid black.)
  readonly property color island: Qt.rgba(base.r, base.g, base.b, isLight ? 0.50 : 0.36)
  readonly property color raised: Qt.rgba(fg.r, fg.g, fg.b, isLight ? 0.12 : 0.13)
  readonly property color hover: Qt.rgba(fg.r, fg.g, fg.b, isLight ? 0.14 : 0.16)
  readonly property color border: Qt.rgba(fg.r, fg.g, fg.b, isLight ? 0.13 : 0.09)
  readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, isLight ? 0.16 : 0.20)

  // Status colours are fixed per mode — a low battery has to read as "low"
  // whatever the wallpaper is doing — but the pastels that work on black are
  // invisible on white, so each has a darker twin.
  readonly property color good: isLight ? "#2e7d32" : "#a6e3a1"
  readonly property color warn: isLight ? "#a35c00" : "#f9e2af"
  readonly property color crit: isLight ? "#c62828" : "#f38ba8"

  // ------------------------------------------------------------- dimensions
  // The display is 1920x1200 at scale 1.5, so only 1280x800 logical pixels.
  // Everything here is deliberately compact.
  readonly property int barHeight: 34
  readonly property int islandHeight: 26
  readonly property int gap: 6          // between islands
  readonly property int margin: 4       // island -> screen edge
  readonly property int padding: 10     // island edge -> content
  readonly property int spacing: 8      // between items inside an island

  // Words are Inter, like the rest of the desktop (fontconfig package);
  // icons are Nerd Font glyphs, which only the Nerd Font has; the clock skins
  // and code keep the monospace. Numbers in Inter use tabular digits
  // (`font.features: Theme.tabular`) so counters and percentages don't jiggle.
  readonly property string textFamily: "Inter"
  readonly property string iconFamily: "FantasqueSansM Nerd Font"
  readonly property string monoFamily: "FantasqueSansM Nerd Font"
  readonly property var tabular: ({ "tnum": 1 })
  // Older name, kept for anything that still asks for it: the icon font.
  readonly property string fontFamily: iconFamily
  readonly property int fontSize: 13
  readonly property int iconSize: 14
  readonly property int smallSize: 11

  readonly property int animFast: 140
  // The motion scale: the speeds the shell's animations are measured in.
  readonly property int motionTap: 90
  readonly property int motionQuick: 160
  readonly property int motionBase: 280
  readonly property int motionMorph: 520
  // Glows, backdrops and the palette: slow enough to never draw the eye.
  readonly property int motionAmbient: 900
  readonly property int animSlow: 260
}
