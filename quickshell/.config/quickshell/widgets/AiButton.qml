// AiButton.qml — slides the AI assistant in and out.
//
// Left click toggles, right click quits the assistant entirely.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    id: glyph

    anchors.centerIn: parent
    text: Icons.ai
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    // Accent while the panel is on screen, a dimmer tint while it is merely
    // loaded, so you can tell "running but hidden" from "not started".
    color: AiAssistant.shown ? Theme.accent : AiAssistant.running ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
  }

  // Pulse while chromium is starting up — cold start takes a few seconds and
  // silence would read as a dead button.
  SequentialAnimation on opacity {
    running: starting.running
    loops: Animation.Infinite

    NumberAnimation {
      to: 0.4
      duration: 500
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
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
      if (event.button === Qt.RightButton) {
        AiAssistant.quit();
        return;
      }
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
