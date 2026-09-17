// DrivesButton.qml — connected USB drives.
//
// Its island only exists while at least one drive is plugged in (see Bar.qml),
// so it costs no bar space the rest of the time.
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

    Text {
      id: glyph

      property real pulse: 1

      anchors.verticalCenter: parent.verticalCenter
      text: Icons.usbDrive
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: popup.opened || mouse.containsMouse || Drives.mountedCount > 0 ? Theme.accent : Theme.fgDim
      opacity: Drives.ejecting !== "" ? pulse : 1

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      SequentialAnimation on pulse {
        running: Drives.ejecting !== ""
        loops: Animation.Infinite

        NumberAnimation {
          to: 0.35
          duration: 500
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          to: 1.0
          duration: 500
          easing.type: Easing.InOutSine
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: Drives.drives.length > 1
      text: Drives.drives.length
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

  DrivesPopup {
    id: popup
    anchorItem: root
  }
}
