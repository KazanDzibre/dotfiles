// DrivesPopup.qml — each connected USB drive, and a safe eject for it.
//
// Eject unmounts every partition and then powers the drive off, which is the
// moment it is genuinely safe to pull. The drive then disappears from udisks,
// taking this popup's island with it — so success is reported as a
// notification rather than here, where nobody would see it.
import QtQuick
import qs

Popup {
  id: root

  cardWidth: 290
  align: "center"

  Connections {
    target: Drives

    function onHasDrivesChanged() {
      if (!Drives.hasDrives)
        root.close();
    }
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 20

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "USB DRIVES"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Drives.drives.length + " connected"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  // ------------------------------------------------------------------ drives
  Repeater {
    model: Drives.drives

    delegate: Rectangle {
      id: card

      required property var modelData

      readonly property bool busy: Drives.ejecting === modelData.path
      readonly property string error: Drives.errors[modelData.path] ?? ""

      width: parent.width
      height: body.implicitHeight + 20
      radius: 10
      color: Theme.raised

      Column {
        id: body

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: ejectButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
          width: parent.width
          text: card.modelData.name
          elide: Text.ElideRight
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          color: Theme.fg
        }

        Text {
          width: parent.width
          text: card.modelData.size
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize - 1
          color: Theme.fgDim
        }

        Repeater {
          model: card.modelData.partitions

          delegate: Text {
            required property var modelData

            readonly property bool isMounted: modelData.mountpoints.length > 0

            width: body.width
            text: (modelData.label.length > 0 ? modelData.label : modelData.path.replace("/dev/", "")) + "  ·  " + (isMounted ? modelData.mountpoints[0] : "not mounted")
            elide: Text.ElideMiddle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize - 1
            color: isMounted ? Theme.fg : Theme.fgDim
          }
        }

        Text {
          width: parent.width
          visible: card.error.length > 0
          text: card.error
          wrapMode: Text.WordWrap
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize - 1
          color: Theme.crit
        }
      }

      Rectangle {
        id: ejectButton

        readonly property bool lit: ejectMouse.containsMouse && Drives.ejecting === ""

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 8
        width: ejectRow.implicitWidth + 14
        height: 22
        radius: 11
        color: card.busy ? Theme.accentSoft : lit ? Theme.accent : Theme.hover

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Row {
          id: ejectRow

          anchors.centerIn: parent
          spacing: 4

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.eject
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize - 1
            color: ejectButton.lit ? Theme.base : Theme.fg
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.busy ? "Ejecting…" : "Eject"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize
            font.bold: true
            color: ejectButton.lit ? Theme.base : Theme.fg
          }
        }

        MouseArea {
          id: ejectMouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Drives.ejecting === "" ? Qt.PointingHandCursor : Qt.BusyCursor
          onClicked: Drives.eject(card.modelData)
        }
      }
    }
  }

  Text {
    visible: !Drives.hasDrives
    text: "No USB drives connected."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.fgDim
  }
}
