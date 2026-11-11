// ParallaxWallpaper.qml — the wallpaper, drawn by the shell so it can move.
//
// Each screen's wallpaper is slightly larger than the screen and slides a
// little with the workspace you're on (Wallpaper.parallaxOffset), slower than
// the windows, so they seem to sit in front of it. With parallax off it simply
// fills the screen and stays put.
//
// hyprpaper keeps running underneath on the Background layer: waypaper and
// theme-sync talk to it as before, and it's what shows if the shell isn't
// running. This sits on the Bottom layer above it; the reveal of a new
// wallpaper (WallpaperReveal.qml) maps later on the same layer, so it lands
// on top of this.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData
      screen: modelData

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      color: "black"
      exclusionMode: ExclusionMode.Ignore
      focusable: false

      // Purely visual: everything goes through to the desktop.
      mask: Region {}

      WlrLayershell.namespace: "quickshell:wallpaper"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      readonly property real travel: Wallpaper.parallaxTravel(win.width)
      readonly property real offset: Wallpaper.parallaxOffset(win.screen, win.width)

      // Two images, so a new wallpaper is only shown once it has fully loaded:
      // `front` is what's on screen, `back` loads the next one.
      property string shown: ""

      Connections {
        target: Wallpaper
        function onCurrentChanged() {
          win.load();
        }
      }
      Component.onCompleted: win.load()

      function load() {
        if (!Wallpaper.current || "file://" + Wallpaper.current === win.shown)
          return;
        back.source = "file://" + Wallpaper.current;
      }

      Image {
        id: back
        visible: false
        asynchronous: true
        cache: false
        sourceSize.width: win.width * 1.6
        sourceSize.height: win.height * 1.6
        onStatusChanged: {
          if (status === Image.Ready) {
            win.shown = source;
            front.source = source;
          }
        }
      }

      Image {
        id: front

        // Wider than the screen by the parallax travel, and as much taller
        // as keeps the picture's proportions; centred vertically.
        width: win.width + win.travel
        height: win.height * (win.width + win.travel) / Math.max(1, win.width)
        y: (win.height - height) / 2
        x: -win.offset
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: win.width * 1.6
        sourceSize.height: win.height * 1.6

        // Slower and softer than the windows' slide, which is what makes it
        // read as depth.
        Behavior on x {
          NumberAnimation {
            duration: 620
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: 620
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
          }
        }
      }
    }
  }
}
