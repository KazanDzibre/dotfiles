// UpdatesButton.qml — pending package count.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 4

    // Spinner and status icon are separate elements: an `on rotation`
    // animation owns the property, so a shared icon would stay tilted at
    // whatever angle the spin stopped on.
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: Theme.iconSize + 2
      height: Theme.iconSize + 2

      Text {
        anchors.centerIn: parent
        visible: Updates.busy
        text: Icons.refresh
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: Theme.fgDim

        RotationAnimation on rotation {
          running: Updates.busy
          loops: Animation.Infinite
          from: 0
          to: 360
          duration: 1100
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !Updates.busy
        text: Updates.count > 0 ? Icons.updates : Icons.upToDate
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: Updates.count > 0 ? Theme.warn : popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

        Behavior on color {
          ColorAnimation {
            duration: Theme.animSlow
          }
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: Updates.count > 0
      text: Updates.count
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

  UpdatesPopup {
    id: popup
    anchorItem: root
  }
}
