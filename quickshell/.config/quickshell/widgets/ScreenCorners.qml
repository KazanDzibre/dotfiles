// ScreenCorners.qml — rounds off the screen's four corners, so the whole
// display reads as one rounded panel like the windows and pills on it.
//
// Four tiny windows per screen rather than one covering it: a full-screen
// layer, even a transparent one, can stop a fullscreen game or video from
// going straight to the display. Each takes no input at all, so nothing under
// a corner is ever blocked.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs

Scope {
  id: root

  // Window rounding (10) plus the gap around windows (2), so the corners line
  // up with the windows' own.
  property int radius: 12

  component Corner: PanelWindow {
    id: corner

    required property var modelData
    property bool top: true
    property bool left: true

    screen: modelData
    anchors {
      top: corner.top
      bottom: !corner.top
      left: corner.left
      right: !corner.left
    }
    implicitWidth: root.radius
    implicitHeight: root.radius
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false

    WlrLayershell.namespace: "quickshell:corners"
    WlrLayershell.layer: WlrLayer.Overlay

    // No input region: clicks go straight through to whatever is underneath.
    mask: Region {}

    // The square minus a quarter circle, filled black.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: "black"
        strokeWidth: -1

        // The curve is drawn for the top-left corner; the others are mirrors.
        startX: 0
        startY: 0
        PathLine {
          x: root.radius
          y: 0
        }
        PathArc {
          x: 0
          y: root.radius
          radiusX: root.radius
          radiusY: root.radius
          direction: PathArc.Counterclockwise
        }
        PathLine {
          x: 0
          y: 0
        }
      }

      transform: Scale {
        origin.x: root.radius / 2
        origin.y: root.radius / 2
        xScale: corner.left ? 1 : -1
        yScale: corner.top ? 1 : -1
      }
    }
  }

  Variants {
    model: Quickshell.screens
    Corner {
      top: true
      left: true
    }
  }
  Variants {
    model: Quickshell.screens
    Corner {
      top: true
      left: false
    }
  }
  Variants {
    model: Quickshell.screens
    Corner {
      top: false
      left: true
    }
  }
  Variants {
    model: Quickshell.screens
    Corner {
      top: false
      left: false
    }
  }
}
