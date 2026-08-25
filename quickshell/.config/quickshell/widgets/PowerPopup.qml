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

  onOpenedChanged: {
    if (!opened)
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

  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
  }

  // Keep awake belongs here rather than in the bar: it is a session behaviour,
  // like everything else in this panel, and it is off almost all the time — so
  // it earns a row here instead of permanent bar space. While it is on, an
  // indicator appears next to the battery.
  Rectangle {
    width: parent.width
    height: 34
    radius: 9
    color: awakeHover.containsMouse ? Theme.hover : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    Text {
      id: awakeGlyph
      anchors.left: parent.left
      anchors.leftMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      text: IdleInhibit.enabled ? Icons.coffee : Icons.coffeeOff
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: IdleInhibit.enabled ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Column {
      anchors.left: awakeGlyph.right
      anchors.leftMargin: 10
      anchors.right: awakeSwitch.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        width: parent.width
        text: "Keep awake"
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }

      Text {
        width: parent.width
        text: IdleInhibit.enabled ? "Screen won't lock or sleep" : "Idle timeout is active"
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize - 1
        color: Theme.fgDim
      }
    }

    Rectangle {
      id: awakeSwitch

      anchors.right: parent.right
      anchors.rightMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      width: 36
      height: 20
      radius: 10
      color: IdleInhibit.enabled ? Theme.accent : Theme.raised

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      Rectangle {
        x: IdleInhibit.enabled ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: IdleInhibit.enabled ? Theme.base : Theme.fgDim

        Behavior on x {
          NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.OutBack
          }
        }
      }
    }

    MouseArea {
      id: awakeHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: IdleInhibit.toggle()
    }
  }
}
