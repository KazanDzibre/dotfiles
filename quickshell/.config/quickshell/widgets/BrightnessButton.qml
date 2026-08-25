// BrightnessButton.qml — opens the display controls; scroll to dim without
// opening anything.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Backlight.brightness < 0.4 ? Icons.brightnessLow : Icons.brightness
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  WheelHandler {
    onWheel: event => Backlight.setBrightness(Backlight.brightness + (event.angleDelta.y > 0 ? 0.05 : -0.05))
  }

  BrightnessPopup {
    id: popup
    anchorItem: root
  }
}
