// WindowsButton.qml — opens the open-windows panel.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Item {
  id: root

  readonly property int count: ToplevelManager.toplevels ? ToplevelManager.toplevels.values.length : 0

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.windows
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.count > 0
      text: root.count
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      color: Theme.fg
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  WindowsPopup {
    id: popup
    anchorItem: root
  }
}
