// NotificationButton.qml — bell with an unread count; right click for DND.
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
      anchors.verticalCenter: parent.verticalCenter
      text: Notifications.doNotDisturb ? Icons.bellOff : Notifications.count > 0 ? Icons.bellBadge : Icons.bellOutline
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: Notifications.doNotDisturb ? Theme.fgDim : Notifications.count > 0 ? Theme.accent : popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: Notifications.count > 0
      text: Notifications.count
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      if (event.button === Qt.RightButton) {
        Notifications.doNotDisturb = !Notifications.doNotDisturb;
        return;
      }
      popup.toggle();
    }
  }

  NotificationPopup {
    id: popup
    anchorItem: root
  }
}
