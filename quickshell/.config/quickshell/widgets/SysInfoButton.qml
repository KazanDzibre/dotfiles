// SysInfoButton.qml — one glyph standing in for CPU/memory/disk.
//
// The bar used to carry three live percentages, which cost ~200px. Collapsing
// them into a single icon keeps the at-a-glance signal — the glyph takes the
// warning colour of whichever metric is worst — and gives the width back to the
// system tray.
import QtQuick
import qs

Item {
  id: root

  readonly property real worst: Math.max(SysInfo.cpu, SysInfo.memory, SysInfo.disk)
  readonly property bool alarming: worst >= 0.75

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.chip
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: root.worst >= 0.9 ? Theme.crit : root.worst >= 0.75 ? Theme.warn : popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animSlow
      }
    }

    // Only nags when something is actually saturated.
    SequentialAnimation on opacity {
      running: root.worst >= 0.9
      loops: Animation.Infinite

      NumberAnimation {
        to: 0.45
        duration: 800
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1.0
        duration: 800
        easing.type: Easing.InOutSine
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  SysInfoPopup {
    id: popup
    anchorItem: root
  }
}
