// ClipboardButton.qml — opens clipboard history. Also on SUPER+V.
import QtQuick
import qs

Item {
  id: root

  readonly property bool wantsKeyboard: popup.wantsKeyboard

  function toggle() {
    popup.toggle();
  }

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.clipboard
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

  ClipboardPopup {
    id: popup
    anchorItem: root
  }
}
