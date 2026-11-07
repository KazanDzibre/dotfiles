// WallpaperReveal.qml — the new wallpaper growing out from the middle.
//
// hyprpaper can only swap an image, not animate it, so the animation is ours:
// one layer-shell surface per screen on the Bottom layer — above hyprpaper's
// Background surface, below every window and the bar. When Wallpaper.apply()
// fires, each draws the new image masked by a circle that grows from the centre
// until it covers the screen. waypaper is applying the same image underneath at
// the same time; once both the animation and waypaper are done, the surface
// unmaps and what's left is the real wallpaper, pixel for pixel the same.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData
      screen: modelData

      property bool active: false
      property bool grown: false
      property real radius: 0

      // Half the diagonal reaches the corners; the extra covers the soft edge.
      readonly property real fullRadius: Math.sqrt(width * width + height * height) / 2 + 80

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      focusable: false
      visible: active

      // Purely visual — clicks go straight through to the desktop.
      mask: Region {}

      WlrLayershell.namespace: "quickshell:wallpaper-reveal"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Connections {
        target: Wallpaper

        function onRevealRequested(path) {
          grow.stop();
          finish.stop();
          win.grown = false;
          win.radius = 0;
          image.source = "file://" + path;
          win.active = true;
          win.tryStart();
        }

        function onApplyingChanged() {
          win.tryFinish();
        }
      }

      // The full-size image decodes asynchronously; start once it's in.
      function tryStart() {
        if (!win.active || grow.running || win.grown)
          return;
        if (image.status === Image.Ready)
          grow.start();
        else if (image.status === Image.Error || image.status === Image.Null)
          win.active = false;
      }

      function tryFinish() {
        if (win.active && win.grown && !Wallpaper.applying)
          finish.restart();
      }

      // Give hyprpaper a moment to actually put the new frame up before we
      // stop covering it.
      Timer {
        id: finish
        interval: 450
        onTriggered: {
          win.active = false;
          win.grown = false;
          win.radius = 0;
        }
      }

      ParallelAnimation {
        id: grow

        NumberAnimation {
          target: win
          property: "radius"
          from: 0
          to: win.fullRadius
          duration: 1400
          easing.type: Easing.InOutCubic
        }
        NumberAnimation {
          target: revealed
          property: "scale"
          from: 1.1
          to: 1
          duration: 1400
          easing.type: Easing.InOutCubic
        }

        onFinished: {
          win.grown = true;
          win.tryFinish();
        }
      }

      Image {
        id: image
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: win.width * 2
        sourceSize.height: win.height * 2

        onStatusChanged: win.tryStart()
      }

      Item {
        id: circle
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
          anchors.centerIn: parent
          width: win.radius * 2
          height: width
          radius: width / 2
          color: "white"
        }
      }

      MultiEffect {
        id: revealed
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: circle
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.25
      }
    }
  }
}
