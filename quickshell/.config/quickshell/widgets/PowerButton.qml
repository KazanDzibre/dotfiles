// PowerButton.qml — opens the session actions.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.power
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    // The one control on the bar that can end your session — it gets the
    // warning colour on hover rather than the accent.
    color: popup.visible || mouse.containsMouse ? Theme.crit : Theme.fgDim

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

  PowerPopup {
    id: popup
    anchorItem: root
  }
}
