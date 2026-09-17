// ToolsIsland.qml — screenshot, clipboard, system health and updates, folded
// behind a single chevron.
//
// On this 1280px-wide screen the bar had about 110px to spare once the media
// and tray islands appeared, and nothing in here needs to be on show all the
// time: screenshot and clipboard have keys of their own (Print, SUPER+SHIFT+V),
// and the two indicators only matter when they're complaining. So the group
// folds down to one glyph, and that glyph takes the colour of whatever inside
// is complaining loudest — folding the group away never hides a warning.
import QtQuick
import qs

Row {
  id: root

  property bool expanded: false

  readonly property bool wantsKeyboard: clipboard.wantsKeyboard

  // Mirrors the thresholds SysInfoButton and UpdatesButton colour themselves by.
  readonly property real worstLoad: Math.max(SysInfo.cpu, SysInfo.memory, SysInfo.disk)
  readonly property color alert: worstLoad >= 0.9 ? Theme.crit : worstLoad >= 0.75 || Updates.count > 0 ? Theme.warn : Theme.fgDim
  readonly property bool alerting: worstLoad >= 0.75 || Updates.count > 0

  // Called by the SUPER+SHIFT+V shortcut in Bar.qml.
  function toggleClipboard() {
    if (root.expanded) {
      clipboard.toggle();
      return;
    }
    // The popup anchors to the clipboard button, which isn't anywhere useful
    // until the drawer has finished sliding open.
    root.expanded = true;
    openClipboard.restart();
  }

  spacing: 9

  Timer {
    id: openClipboard
    interval: Theme.animSlow + 40
    onTriggered: clipboard.toggle()
  }

  Item {
    id: drawer

    anchors.verticalCenter: parent.verticalCenter
    width: root.expanded ? contents.implicitWidth : 0
    height: 18
    clip: true
    // Out of the Row's layout while shut, so it doesn't leave a spacing gap.
    visible: width > 0

    Behavior on width {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutQuint
      }
    }

    Row {
      id: contents

      // Pinned to the chevron's side, so the buttons slide out from it.
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      opacity: root.expanded ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animFast
        }
      }

      ScreenshotButton {
        anchors.verticalCenter: parent.verticalCenter
      }

      ClipboardButton {
        id: clipboard
        anchors.verticalCenter: parent.verticalCenter
      }

      SysInfoButton {
        anchors.verticalCenter: parent.verticalCenter
      }

      UpdatesButton {
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Item {
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: 16
    implicitHeight: 18

    Text {
      anchors.centerIn: parent
      text: Icons.chevronLeft
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: root.alerting && !root.expanded ? root.alert : root.expanded || toggleMouse.containsMouse ? Theme.accent : Theme.fgDim
      // Points the way the drawer opens; turned round, the way it closes.
      rotation: root.expanded ? 180 : 0

      Behavior on rotation {
        NumberAnimation {
          duration: Theme.animSlow
          easing.type: Easing.OutBack
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    MouseArea {
      id: toggleMouse

      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.expanded = !root.expanded
    }
  }
}
