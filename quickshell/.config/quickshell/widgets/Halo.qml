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
    // Wider than the spacing between rings, so neighbours overlap and the
    // steps melt into one fade instead of reading as separate lines.
    property real w: 2.4

    x: root.target.x - d
    y: root.target.y - d + dy
    width: root.target.width + d * 2
    height: root.target.height + d * 2
    radius: (root.target.radius ?? 0) + d
    scale: root.target.scale
    color: "transparent"
    border.width: w
    border.color: Qt.rgba(ink.r, ink.g, ink.b, a)
  }

  // Underneath: the shadow, offset a little downward, darker near the edge.
  Repeater {
    model: root.shadow && root.target ? [[2, 0.14, 1], [4, 0.09, 2], [6, 0.058, 3], [8, 0.037, 4], [10, 0.024, 5], [12, 0.015, 6], [14, 0.009, 7], [16, 0.005, 8]] : []

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
    // A panel (shadow: true) already has the glass's own border and rim light, so
    // its light halo would only be a third line beside them.
    model: root.target && !root.shadow ? [[1.5, 0.06], [3.5, 0.03], [5.5, 0.012]] : []

    delegate: Ring {
      required property var modelData
      d: modelData[0]
      a: modelData[1] * root.strength
    }
  }
}
