// NotificationPopup.qml — notification history.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  cardWidth: 350
  align: "right"

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 24

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "NOTIFICATIONS"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      // Do not disturb
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: Notifications.doNotDisturb ? Theme.accentSoft : dndHover.containsMouse ? Theme.hover : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.centerIn: parent
          text: Notifications.doNotDisturb ? Icons.bellOff : Icons.bell
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Notifications.doNotDisturb ? Theme.accent : Theme.fgDim
        }

        MouseArea {
          id: dndHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
        }
      }

      // Clear all
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: Notifications.count > 0
        width: 24
        height: 24
        radius: 12
        color: clearHover.containsMouse ? Theme.crit : "transparent"

        Text {
          anchors.centerIn: parent
          text: Icons.clearAll
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: clearHover.containsMouse ? Theme.base : Theme.fgDim
        }

        MouseArea {
          id: clearHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Notifications.clearAll()
        }
      }
    }
  }

  Text {
    width: parent.width
    visible: Notifications.doNotDisturb
    text: "Do not disturb is on — notifications are collected here without popping up."
    wrapMode: Text.WordWrap
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.fgDim
  }

  // -------------------------------------------------------------- the list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 340)
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: Notifications.count > 0

    Column {
      id: list
      width: parent.width
      spacing: 2

      Repeater {
        model: Notifications.history

        delegate: NotificationCard {
          id: card

          required property var modelData

          notification: modelData
          onDismissed: Notifications.dismiss(card.modelData)
        }
      }
    }
  }

  // ------------------------------------------------------------ empty state
  Row {
    width: parent.width
    spacing: 8
    visible: Notifications.count === 0

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.bellOutline
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: Theme.fgDim
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Nothing to see here."
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fgDim
    }
  }
}
