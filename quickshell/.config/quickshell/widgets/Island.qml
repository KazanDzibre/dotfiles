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

  Row {
    id: layout
    anchors.centerIn: parent
    spacing: root.spacing
  }

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Theme.animSlow
      easing.type: Easing.OutQuint
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
