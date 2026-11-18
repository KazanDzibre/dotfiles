// ClockFace.qml — the island's time, in whichever skin ClockStyle names: an LED
// display, an amber one, or plain rolling digits. Sizes itself to
// the face it shows.
import QtQuick
import qs

Loader {
  id: root

  property string text: ""
  // The island's accent and ink, passed in because they belong to the island.
  property color accent: Theme.accent
  property color ink: Theme.fg

  sourceComponent: ClockStyle.skin === "led" || ClockStyle.skin === "amber" ? segments : cards

  Component {
    id: segments

    SegmentClock {
      text: root.text
      color: ClockStyle.skin === "amber" ? "#ffb000" : root.accent
    }
  }

  Component {
    id: cards

    RollingText {
      text: root.text
      bold: true
      color: root.ink
    }
  }
}
