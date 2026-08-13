// Clock.qml — time, date, and a calendar on click.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.calendar
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: popup.opened ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.time
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Theme.fg
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.date
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fgDim
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  CalendarPopup {
    id: popup
    anchorItem: root
  }
}
