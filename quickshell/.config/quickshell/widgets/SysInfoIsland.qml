// SysInfoIsland.qml — CPU, memory, disk, and pending package updates.
import QtQuick
import Quickshell
import qs

Row {
  id: root

  spacing: 9

  Metric {
    anchors.verticalCenter: parent.verticalCenter
    glyph: Icons.cpu
    value: SysInfo.cpu
  }

  Metric {
    anchors.verticalCenter: parent.verticalCenter
    glyph: Icons.memory
    value: SysInfo.memory
  }

  Metric {
    anchors.verticalCenter: parent.verticalCenter
    glyph: Icons.disk
    value: SysInfo.disk
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: 14
    color: Theme.border
  }

  // ----------------------------------------------------------- updates badge
  Item {
    id: updatesButton

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: updatesRow.implicitWidth
    implicitHeight: 18

    Row {
      id: updatesRow
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
          color: Updates.count > 0 ? Theme.warn : Theme.fgDim

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
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: updatesPopup.toggle()
    }
  }

  UpdatesPopup {
    id: updatesPopup
    anchorItem: updatesButton
  }
}
