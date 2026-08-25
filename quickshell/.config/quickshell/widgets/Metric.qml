// Metric.qml — one icon + percentage readout for the system island.
import QtQuick
import qs

Row {
  id: root

  property string glyph
  property real value            // 0..1

  // Only shout when it matters; otherwise stay in the wallpaper's palette.
  readonly property color tint: value >= 0.9 ? Theme.crit : value >= 0.75 ? Theme.warn : Theme.accent

  spacing: 4

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
    // Fixed width, right aligned: the row must not twitch as digits change.
    width: 26
    horizontalAlignment: Text.AlignRight
    text: Math.round(root.value * 100) + "%"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.fg
  }
}
