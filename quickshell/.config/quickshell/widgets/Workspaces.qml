// Workspaces.qml — live Hyprland workspaces.
//
// Each existing workspace is a pill; the focused one widens and takes the
// accent colour. Click to switch, scroll anywhere on the group to cycle.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  // Hyprland reports workspaces in creation order, so sort by id. Negative ids
  // are special workspaces (your SUPER+S scratchpad) — those get their own
  // indicator rather than a slot in the row.
  ScriptModel {
    id: wsModel
    values: Array.from(Hyprland.workspaces.values).filter(w => w.id > 0).sort((a, b) => a.id - b.id)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Repeater {
      model: wsModel

      delegate: Rectangle {
        id: pill

        required property var modelData
        readonly property bool active: modelData.focused
        readonly property bool urgent: modelData.urgent

        implicitWidth: active ? 26 : 18
        implicitHeight: 18
        radius: height / 2

        color: active ? Theme.accent : urgent ? Theme.crit : mouse.containsMouse ? Theme.hover : Theme.raised

        Text {
          anchors.centerIn: parent
          text: pill.modelData.name
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          font.bold: pill.active
          color: pill.active || pill.urgent ? Theme.base : Theme.fgDim
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: pill.modelData.activate()
        }

        Behavior on implicitWidth {
          NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.OutBack
          }
        }
        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }
      }
    }

    // Scratchpad indicator — only present while the special workspace has
    // something in it.
    Rectangle {
      readonly property var special: Array.from(Hyprland.workspaces.values).find(w => w.id < 0) ?? null

      visible: special !== null
      implicitWidth: 18
      implicitHeight: 18
      radius: height / 2
      color: "transparent"
      border.width: 1
      border.color: Theme.accent

      Text {
        anchors.centerIn: parent
        text: "●"
        font.pixelSize: Theme.smallSize - 2
        color: Theme.accent
      }
    }
  }

  WheelHandler {
    onWheel: event => Hyprland.dispatch(event.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
  }
}
