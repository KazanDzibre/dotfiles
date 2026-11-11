// Island.qml — the rounded pill that every group of bar content sits in.
//
// Sizes itself to its contents and animates that width, so a widget that grows
// (a longer song title, a new workspace) slides open instead of snapping.
import QtQuick
import qs

Rectangle {
  id: root

  default property alias content: layout.data
  property int spacing: Theme.spacing
  property int padding: Theme.padding

  // Set false to fade the island out; it leaves the layout once fully hidden.
  property bool shown: true

  implicitWidth: layout.implicitWidth + padding * 2
  implicitHeight: Theme.islandHeight
  radius: height / 2

  // Brighter on hover, pressed in a touch while clicked: the same feel on every
  // pill. The rim is the island's: a light line (dark in light mode) with a
  // faint halo just outside it, so the pill keeps its shape on any wallpaper.
  readonly property color rimTone: Theme.isLight ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)

  color: hover.hovered ? Qt.tint(Theme.island, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.07)) : Theme.island
  border.width: 1
  border.color: Qt.rgba(rimTone.r, rimTone.g, rimTone.b, (Theme.isLight ? 0.12 : 0.16) + (hover.hovered ? 0.06 : 0))

  HoverHandler {
    id: hover
  }

  // Passive: sees the press without taking it from the widget inside.
  PointHandler {
    id: press
  }

  Repeater {
    model: [[1.5, 0.08], [3, 0.04], [5, 0.018]]

    delegate: Rectangle {
      required property var modelData
      readonly property real d: modelData[0]

      x: -d
      y: -d
      z: -1
      width: root.width + d * 2
      height: root.height + d * 2
      radius: root.radius + d
      color: "transparent"
      border.width: 1.5
      border.color: Qt.rgba(root.rimTone.r, root.rimTone.g, root.rimTone.b, modelData[1] * (Theme.isLight ? 0.7 : 1))
    }
  }

  opacity: shown ? 1 : 0

  // At login (Welcome.qml) each pill drops in from above the bar, a beat after
  // the one before it; -1 opts a pill out.
  property int dropDelay: -1
  readonly property bool dropping: Welcome.entrance && dropDelay >= 0

  transform: Translate {
    id: drop
    y: root.dropping ? -60 : 0
  }

  SequentialAnimation {
    running: root.dropping
    PauseAnimation {
      duration: 350 + Math.max(0, root.dropDelay)
    }
    NumberAnimation {
      target: drop
      property: "y"
      to: 0
      duration: 700
      easing.type: Easing.BezierSpline
      easing.bezierCurve: [0.34, 1.32, 0.5, 1, 1, 1]
    }
  }
  scale: (shown ? 1 : 0.9) * (press.active ? 0.97 : 1)
  visible: opacity > 0.01

  // For a pill that opens something when clicked anywhere on it.
  property bool tappable: false
  signal tapped

  MouseArea {
    anchors.fill: parent
    enabled: root.tappable
    visible: root.tappable
    cursorShape: Qt.PointingHandCursor
    onClicked: root.tapped()
  }

  // Content can be wider than the pill for a moment while it shrinks, so it's
  // clipped here rather than on the pill itself, which would also cut off the
  // halo around it.
  Item {
    anchors.fill: parent
    clip: true

    Row {
      id: layout
      anchors.centerIn: parent
      spacing: root.spacing
    }
  }

  Behavior on implicitWidth {
    NumberAnimation {
      duration: 380
      easing.type: Easing.BezierSpline
      easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animFast
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: press.active ? 90 : 380
      easing.type: Easing.BezierSpline
      easing.bezierCurve: press.active ? [0.2, 0, 0.4, 1, 1, 1] : [0.34, 1.56, 0.64, 1, 1, 1]
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: Theme.animSlow
    }
  }
}
