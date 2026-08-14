// MetricBar.qml — a labelled usage bar for the system panel.
import QtQuick
import qs

Column {
  id: root

  property string glyph
  property string label
  property real value            // 0..1
  property string detail: ""

  readonly property color tint: value >= 0.9 ? Theme.crit : value >= 0.75 ? Theme.warn : Theme.accent

  spacing: 5

  Item {
    width: parent.width
    height: 16

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: root.tint

        Behavior on color {
          ColorAnimation {
            duration: Theme.animSlow
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.detail.length > 0 ? root.detail + "   " + Math.round(root.value * 100) + "%" : Math.round(root.value * 100) + "%"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  Rectangle {
    width: parent.width
    height: 5
    radius: 2.5
    color: Theme.raised

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.value))
      height: parent.height
      radius: parent.radius
      color: root.tint

      Behavior on width {
        NumberAnimation {
          duration: 220
          easing.type: Easing.OutQuad
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: Theme.animSlow
        }
      }
    }
  }
}
