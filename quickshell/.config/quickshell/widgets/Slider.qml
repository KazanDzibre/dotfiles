// Slider.qml — a themed horizontal slider.
//
// Reports drags through `moved` rather than writing `value` itself, so the
// owner stays the single source of truth (the real volume, not the knob).
import QtQuick
import qs

Item {
  id: root

  property real value: 0            // 0..1
  property color fill: Theme.accent

  // `enabled` is Item's own property — setting it false already blocks the
  // MouseArea, so we only need to reflect it visually.
  signal moved(real value)

  implicitHeight: 20

  function clamp(v) {
    return Math.max(0, Math.min(1, v));
  }

  Rectangle {
    id: track

    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: 3
    color: Theme.raised

    Rectangle {
      width: Math.max(height, track.width * root.clamp(root.value))
      height: parent.height
      radius: 3
      color: root.enabled ? root.fill : Theme.fgDim

      Behavior on width {
        NumberAnimation {
          duration: 90
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }
  }

  Rectangle {
    id: knob

    x: (track.width - width) * root.clamp(root.value)
    anchors.verticalCenter: parent.verticalCenter
    width: 12
    height: 12
    radius: 6
    color: root.enabled ? root.fill : Theme.fgDim
    border.width: 2
    border.color: Theme.base
    scale: mouse.pressed ? 1.25 : 1

    Behavior on x {
      NumberAnimation {
        duration: 90
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animFast
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    anchors.margins: -6      // easier to grab than a 6px track
    cursorShape: Qt.PointingHandCursor

    function report(mouseX) {
      root.moved(root.clamp((mouseX - 6) / track.width));
    }

    onPressed: event => report(event.x)
    onPositionChanged: event => {
      if (pressed)
        report(event.x);
    }
  }
}
