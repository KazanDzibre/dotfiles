// AiButton.qml — slides the AI assistant in and out.
//
// Left click toggles, right click quits the assistant entirely.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  // Halo behind the glyph while the panel is on screen, so the button reads as
  // "held down" for as long as the drawer is out. It grows in on roughly the
  // same curve Hyprland slides the panel with, which ties the two together.
  Rectangle {
    id: halo

    anchors.centerIn: parent
    width: 20
    height: 20
    radius: width / 2

    color: Theme.accentSoft
    opacity: AiChat.open || AiAssistant.shown ? 1 : 0
    scale: AiChat.open || AiAssistant.shown ? 1 : 0.5

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutBack
      }
    }
  }

  Text {
    id: glyph

    anchors.centerIn: parent
    text: Icons.ai
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    // Accent while the panel is on screen, a dimmer tint while it is merely
    // loaded, so you can tell "running but hidden" from "not started".
    color: AiChat.open || AiAssistant.shown ? Theme.accent : AiAssistant.running ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    // Hover lift and a dip on press — the click has to feel like it landed
    // before the panel has finished sliding.
    scale: mouse.pressed ? 0.86 : mouse.containsMouse ? 1.12 : 1

    Behavior on scale {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.OutBack
      }
    }
  }

  // Pulse while chromium is starting up — cold start takes a few seconds and
  // silence would read as a dead button. alwaysRunToEnd matters here: without
  // it, a window that appears mid-fade leaves the glyph stuck half transparent.
  SequentialAnimation {
    running: starting.running
    loops: Animation.Infinite
    alwaysRunToEnd: true

    NumberAnimation {
      target: root
      property: "opacity"
      to: 0.4
      duration: 500
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: root
      property: "opacity"
      to: 1.0
      duration: 500
      easing.type: Easing.InOutSine
    }
  }

  Timer {
    id: starting
    interval: 15000
    running: false
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      // Left click is the web app — it has the logged-in session, history and
      // file uploads, which is what actually gets used. The native panel is
      // still here on right click, but it is the secondary tool now.
      if (event.button === Qt.RightButton) {
        Dashboard.close();
        AiChat.toggle();
        return;
      }
      AiChat.close();
      if (!AiAssistant.running)
        starting.restart();
      AiAssistant.toggle();
    }
  }

  Connections {
    target: AiAssistant

    function onRunningChanged() {
      if (AiAssistant.running)
        starting.stop();
    }
  }
}
