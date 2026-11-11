// Halo.qml — the soft edge around a rounded shape, the same one the island
// has: a few ever fainter outlines just outside it (light on a dark theme,
// dark on a light one), and optionally a shadow underneath for things that
// float above the windows.
//
// Plain outlines rather than a blur, so they follow a shape that is resizing
// for free. Put it next to the shape it surrounds (a sibling, declared before
// it) and point `target` at that shape.
import QtQuick
import qs

Item {
  id: root

  property Item target: null
  property bool shadow: false

  // The rim colour's base; each ring is a fainter step of it.
  readonly property color tone: Theme.isLight ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
  readonly property real strength: Theme.isLight ? 0.7 : 1

  visible: target !== null && target.visible
  opacity: target ? target.opacity : 0

  component Ring: Rectangle {
    required property real d
    required property real a
    property real dy: 0
    property color ink: root.tone

    x: root.target.x - d
    y: root.target.y - d + dy
    width: root.target.width + d * 2
    height: root.target.height + d * 2
    radius: (root.target.radius ?? 0) + d
    scale: root.target.scale
    color: "transparent"
    border.width: 1.5
    border.color: Qt.rgba(ink.r, ink.g, ink.b, a)
  }

  // Underneath: the shadow, offset a little downward, darker near the edge.
  Repeater {
    model: root.shadow && root.target ? [[3, 0.16, 2], [6, 0.1, 4], [10, 0.06, 6], [15, 0.03, 8]] : []

    delegate: Ring {
      required property var modelData
      d: modelData[0]
      a: modelData[1]
      dy: modelData[2]
      ink: "black"
    }
  }

  // The halo itself.
  Repeater {
    model: root.target ? [[1.5, 0.09], [3, 0.045], [5, 0.02]] : []

    delegate: Ring {
      required property var modelData
      d: modelData[0]
      a: modelData[1] * root.strength
    }
  }
}
