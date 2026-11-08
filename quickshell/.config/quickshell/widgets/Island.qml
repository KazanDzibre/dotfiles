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

  color: Theme.island
  border.width: 1
  border.color: Theme.border

  opacity: shown ? 1 : 0
  scale: shown ? 1 : 0.9
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

  Row {
    id: layout
    anchors.centerIn: parent
    spacing: root.spacing
  }

  // Content can be wider than the pill for a moment while it shrinks.
  clip: true

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
      duration: Theme.animFast
      easing.type: Easing.OutBack
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: Theme.animSlow
    }
  }
}
