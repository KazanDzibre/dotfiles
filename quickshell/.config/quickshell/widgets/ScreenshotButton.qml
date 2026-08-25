// ScreenshotButton.qml — left click selects a region, right click for the
// whole screen. Both are also on Print / SUPER+SHIFT+S.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.camera
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    scale: mouse.pressed ? 0.85 : 1

    Behavior on scale {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.OutBack
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      if (event.button === Qt.RightButton)
        Screenshot.fullScreen();
      else
        Screenshot.region();
    }
  }
}
