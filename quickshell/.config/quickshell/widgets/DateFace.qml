// DateFace.qml — the date beside the island's clock in the display skins, in
// the clock's own style: a thin divider, then
//   LED, amber, VFD  the weekday in small caps over the day and month, like
//                    the label panel on an old clock
//   dot matrix       one line, weekday then the day in the accent
// The Plain skin shows a line of text instead (DynamicIsland.qml).
import QtQuick
import qs

Row {
  id: root

  property date date: new Date()
  property string skin: "led"
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

  // LED, amber and VFD.
  Column {
    visible: root.skin === "led" || root.skin === "amber" || root.skin === "vfd"
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
      text: Qt.formatDateTime(root.date, root.skin === "vfd" ? "dd/MM" : "d MMM").toUpperCase()
      font.family: Theme.fontFamily
      font.pixelSize: 9
      font.letterSpacing: 0.8
      color: root.ghost(root.ink, 0.6)
    }
  }

  // Dot matrix.
  Row {
    visible: root.skin === "dots"
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Text {
      anchors.baseline: dayNumber.baseline
      text: Qt.formatDateTime(root.date, "ddd").toUpperCase()
      font.family: Theme.fontFamily
      font.pixelSize: 9
      font.letterSpacing: 1
      color: root.ghost(root.ink, 0.65)
    }
    Text {
      id: dayNumber
      text: Qt.formatDateTime(root.date, "d")
      font.family: Theme.fontFamily
      font.pixelSize: 12
      font.bold: true
      color: root.accent
    }
  }
}
