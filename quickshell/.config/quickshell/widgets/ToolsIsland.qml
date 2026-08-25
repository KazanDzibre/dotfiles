// ToolsIsland.qml — screenshot and clipboard.
//
// Two actions rather than three: the idle inhibitor lives in the power panel
// instead, because it is a session behaviour and because a toggle that is off
// almost all the time doesn't deserve permanent bar space. It shows up in the
// bar only while it is actually on — see SystemIsland.
import QtQuick
import qs

Row {
  id: root

  readonly property bool wantsKeyboard: clipboard.wantsKeyboard

  function toggleClipboard() {
    clipboard.toggle();
  }

  spacing: 10

  ScreenshotButton {
    anchors.verticalCenter: parent.verticalCenter
  }

  ClipboardButton {
    id: clipboard
    anchors.verticalCenter: parent.verticalCenter
  }
}
