// ThemeButton.qml — flips between the light and dark derivations of the
// current pywal palette.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    id: glyph

    anchors.centerIn: parent
    text: Theme.isLight ? Icons.sun : Icons.moon
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
  }

  // Spin the glyph as the mode flips — the icon swap is instant, the motion
  // is what makes it read as a switch.
  RotationAnimation {
    id: spin
    target: glyph
    from: -90
    to: 0
    duration: Theme.animSlow
    easing.type: Easing.OutBack
  }

  Connections {
    target: Theme

    function onModeChanged() {
      spin.restart();
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Theme.toggleMode()
  }
}
