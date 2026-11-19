// VfdClock.qml — the time as a vacuum fluorescent display: bright teal digits
// with a soft glow around them, like a hi-fi deck. The digits roll when they
// change.
import QtQuick
import QtQuick.Effects
import qs

RollingText {
  id: root

  bold: true
  pixelSize: 17

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: root.color
    shadowBlur: 0.9
    shadowOpacity: 0.85
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    autoPaddingEnabled: true
  }
}
