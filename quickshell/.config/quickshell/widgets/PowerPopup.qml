// PowerPopup.qml — lock, sleep, log out, restart, shut down.
//
// Anything that destroys your session asks twice. The first click arms the
// tile, the second runs it, and it disarms itself after a few seconds — enough
// to stop a stray click from ending your session, without a modal dialog.
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Popup {
  id: root

  readonly property int tileWidth: 56
  readonly property int tileHeight: 60

  cardWidth: tileWidth * 5 + 4 * 6 + 28
  align: "right"

  // Which action is waiting for its confirming second click.
  property string armed: ""

  readonly property var actions: [
    {
      id: "lock",
      label: "Lock",
      glyph: Icons.lock,
      confirm: false,
      cmd: ["hyprlock"]
    },
    {
      id: "suspend",
      label: "Sleep",
      glyph: Icons.sleep,
      confirm: false,
      cmd: ["systemctl", "suspend"]
    },
    {
      id: "logout",
      label: "Log out",
      glyph: Icons.logout,
      confirm: true,
      // Mirrors the SUPER+SHIFT+E binding in hyprland.conf.
      cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"]
    },
    {
      id: "reboot",
      label: "Restart",
      glyph: Icons.restart,
      confirm: true,
      cmd: ["systemctl", "reboot"]
    },
    {
      id: "poweroff",
      label: "Shut down",
      glyph: Icons.power,
      confirm: true,
      cmd: ["systemctl", "poweroff"]
    }
  ]

  Timer {
    id: disarmTimer
    interval: 3500
    onTriggered: root.armed = ""
  }

  Process {
    id: runner
  }

  onVisibleChanged: {
    if (!visible)
      root.armed = "";
  }

  function trigger(action) {
    if (action.confirm && root.armed !== action.id) {
      root.armed = action.id;
      disarmTimer.restart();
      return;
    }
    root.armed = "";
    runner.command = action.cmd;
    runner.startDetached();
    root.close();
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 18

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "POWER"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: root.armed !== ""
      text: "click again to confirm"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.crit
    }
  }

  // ------------------------------------------------------------------- tiles
  Row {
    width: parent.width
    spacing: 6

    Repeater {
      model: root.actions

      delegate: Rectangle {
        id: tile

        required property var modelData

        readonly property bool isArmed: root.armed === modelData.id
        readonly property color tone: isArmed ? Theme.crit : hover.containsMouse ? Theme.accent : Theme.fg

        width: root.tileWidth
        height: root.tileHeight
        radius: 10

        color: isArmed ? Qt.rgba(Theme.crit.r, Theme.crit.g, Theme.crit.b, 0.18) : hover.containsMouse ? Theme.hover : Theme.raised

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        scale: hover.containsMouse ? 1.05 : 1.0

        Behavior on scale {
          NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutBack
          }
        }

        Column {
          anchors.centerIn: parent
          spacing: 5

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.modelData.glyph
            font.family: Theme.fontFamily
            font.pixelSize: 20
            color: tile.tone

            Behavior on color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.tileWidth - 6
            horizontalAlignment: Text.AlignHCenter
            text: tile.isArmed ? "Confirm?" : tile.modelData.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize
            font.bold: tile.isArmed
            color: tile.isArmed ? Theme.crit : Theme.fgDim
          }
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.trigger(tile.modelData)
        }
      }
    }
  }
}
