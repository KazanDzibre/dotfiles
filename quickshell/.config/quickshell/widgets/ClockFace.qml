// ClockFace.qml — the island's time, in whichever skin ClockStyle names: an LED
// display (amber too), a dot matrix, a VFD or plain rolling digits. Sizes itself to
// the face it shows.
import QtQuick
import qs

Loader {
  id: root

  property string text: ""
  // The island's accent and ink, passed in because they belong to the island.
  property color accent: Theme.accent
  property color ink: Theme.fg

  sourceComponent: ClockStyle.skin === "dots" ? dots : ClockStyle.skin === "vfd" ? vfd : ClockStyle.retro ? segments : cards

  Component {
    id: segments

    SegmentClock {
      text: root.text
      color: ClockStyle.tint(root.accent)
      digitHeight: 13
      digitWidth: 7
      thickness: 1.7
      spacing: 3
    }
  }

  Component {
    id: dots

    DotClock {
      text: root.text
      color: root.accent
    }
  }

  Component {
    id: vfd

    VfdClock {
      text: root.text
      color: ClockStyle.tint(root.accent)
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
