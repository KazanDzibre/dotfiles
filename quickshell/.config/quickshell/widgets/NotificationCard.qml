// NotificationCard.qml — one notification, used by both the toasts and the
// history panel.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

Rectangle {
  id: root

  required property var notification
  // Toasts sit on the wallpaper and need their own ground; history rows sit
  // inside a card that already has one.
  property bool standalone: false
  property bool showAge: true

  signal dismissed

  width: parent ? parent.width : 300
  implicitHeight: layout.implicitHeight + 20
  height: implicitHeight

  radius: standalone ? 14 : 9
  color: standalone ? Theme.island : hover.containsMouse ? Theme.hover : "transparent"
  border.width: standalone ? 1 : 0
  border.color: Theme.border

  Behavior on color {
    ColorAnimation {
      duration: Theme.animFast
    }
  }

  // Urgency stripe down the left edge — a critical notification should be
  // identifiable without reading it.
  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: 3
    height: parent.height - 18
    radius: 1.5
    color: Notifications.urgencyColor(root.notification)
    visible: root.notification.urgency !== undefined
  }

  Item {
    id: layout

    anchors.left: parent.left
    anchors.leftMargin: 17
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: content.implicitHeight

    readonly property string iconSource: Notifications.iconFor(root.notification)

    IconImage {
      id: appIcon
      anchors.top: parent.top
      anchors.left: parent.left
      visible: layout.iconSource !== ""
      source: layout.iconSource
      implicitSize: 26
      asynchronous: true
    }

    Text {
      anchors.top: parent.top
      anchors.left: parent.left
      visible: layout.iconSource === ""
      width: 26
      horizontalAlignment: Text.AlignHCenter
      text: Icons.bell
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: Notifications.urgencyColor(root.notification)
    }

    Column {
      id: content

      anchors.left: parent.left
      anchors.leftMargin: 34
      anchors.right: parent.right
      spacing: 3

      Item {
        width: parent.width
        height: 14

        Text {
          anchors.left: parent.left
          width: parent.width - (ageLabel.visible ? ageLabel.width + 8 : 0)
          text: root.notification.appName
          elide: Text.ElideRight
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          font.bold: true
          font.letterSpacing: 0.5
          color: Notifications.urgencyColor(root.notification)
        }

        Text {
          id: ageLabel
          anchors.right: parent.right
          visible: root.showAge
          text: Notifications.ageText(root.notification)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          color: Theme.fgDim
        }
      }

      Text {
        width: parent.width
        visible: root.notification.summary.length > 0
        text: root.notification.summary
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        color: Theme.fg
      }

      Text {
        width: parent.width
        visible: root.notification.body.length > 0
        text: root.notification.body
        elide: Text.ElideRight
        maximumLineCount: 3
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText     // the spec allows limited markup in bodies
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize + 1
        color: Theme.fgDim
      }

      // Actions the sending app offered.
      Row {
        width: parent.width
        spacing: 6
        visible: root.notification.actions.length > 0
        topPadding: 3

        Repeater {
          model: root.notification.actions

          delegate: Rectangle {
            id: actionButton

            required property var modelData

            height: 24
            width: Math.min(120, actionLabel.implicitWidth + 20)
            radius: 8
            color: actionHover.containsMouse ? Theme.accent : Theme.raised

            Behavior on color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }

            Text {
              id: actionLabel
              anchors.centerIn: parent
              width: parent.width - 16
              horizontalAlignment: Text.AlignHCenter
              text: actionButton.modelData.text
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize
              color: actionHover.containsMouse ? Theme.base : Theme.fg
            }

            MouseArea {
              id: actionHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                actionButton.modelData.invoke();
                root.dismissed();
              }
            }
          }
        }
      }
    }
  }

  // Dismiss, revealed on hover.
  Rectangle {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 5
    width: 20
    height: 20
    radius: 10
    opacity: hover.containsMouse || closeHover.containsMouse ? 1 : 0
    color: closeHover.containsMouse ? Theme.crit : Theme.raised

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
      }
    }

    Text {
      anchors.centerIn: parent
      text: Icons.close
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: closeHover.containsMouse ? Theme.base : Theme.fgDim
    }

    MouseArea {
      id: closeHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.dismissed()
    }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }
}
