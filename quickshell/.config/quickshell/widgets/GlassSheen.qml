// GlassSheen.qml — the light caught by a sheet of glass: a bright line along
// the top edge that fades down the sides, and a faint glow just inside the top.
// Laid over a pill or panel whose fill is the translucent Theme.island (the
// blur behind it is Hyprland's, see the layer rules in hyprland.lua).
//
// Drawn once into a texture and only redrawn when the size changes, so it
// costs nothing while the surface sits still. Never takes a click.
import QtQuick
import QtQuick.Effects
import qs

Item {
  id: root

  property real radius: height / 2
  // 0..1: how much of the height the rim light reaches before it has faded.
  property real reach: 0.55

  anchors.fill: parent
  enabled: false

  // The rim, full strength everywhere; the mask below fades it downwards.
  Rectangle {
    id: rim
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    border.width: 1
    border.color: Theme.isLight ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.55)
    visible: false
    layer.enabled: true
  }

  Rectangle {
    id: fade
    anchors.fill: parent
    visible: false
    layer.enabled: true
    gradient: Gradient {
      GradientStop {
        position: 0
        color: "white"
      }
      GradientStop {
        position: root.reach
        color: "transparent"
      }
    }
  }

  MultiEffect {
    anchors.fill: parent
    source: rim
    maskEnabled: true
    maskSource: fade
    // A soft ramp: the rim fades out smoothly instead of being cut off.
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  // Light just inside the top, as if from above.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: Math.max(0, root.radius - 1)
    gradient: Gradient {
      GradientStop {
        position: 0
        color: Qt.rgba(1, 1, 1, Theme.isLight ? 0.22 : 0.10)
      }
      GradientStop {
        position: 0.45
        color: Qt.rgba(1, 1, 1, 0)
      }
    }
  }
}
