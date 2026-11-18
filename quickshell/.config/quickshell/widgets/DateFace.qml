// DateFace.qml — the date beside the island's clock in the LED skins: a thin
// divider, then the weekday in small caps over the day and month, like the
// label panel on an old LED clock. The Plain skin shows a line of text instead
// (DynamicIsland.qml).
import QtQuick
import qs

Row {
  id: root

  property date date: new Date()
  // The clock's colour, and the island's ink.
  property color accent: Theme.accent
  property color ink: Theme.fg

  spacing: 7

  function ghost(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  // In the colour of the clock's unlit segments.
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: 14
    color: root.ghost(root.accent, 0.25)
  }

  Column {
    anchors.verticalCenter: parent.verticalCenter
    spacing: -1

    Text {
      text: Qt.formatDateTime(root.date, "ddd").toUpperCase()
      font.family: Theme.fontFamily
      font.pixelSize: 8
      font.bold: true
      font.letterSpacing: 1.4
      color: root.accent
    }
    Text {
      text: Qt.formatDateTime(root.date, "d MMM").toUpperCase()
      font.family: Theme.fontFamily
      font.pixelSize: 9
      font.letterSpacing: 0.8
      color: root.ghost(root.ink, 0.6)
    }
  }
}
