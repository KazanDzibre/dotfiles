// WindowTitle.qml — icon + title of the focused window.
//
// Truncates rather than pushing the centre clock off-centre; at 1280 logical
// pixels wide that matters.
import QtQuick
import Quickshell.Hyprland
import qs

Row {
  id: root

  readonly property var toplevel: Hyprland.activeToplevel
  readonly property string title: toplevel ? toplevel.title : ""
  readonly property string appClass: toplevel && toplevel.lastIpcObject ? (toplevel.lastIpcObject["class"] ?? "") : ""
  readonly property bool hasWindow: title.length > 0

  property int maxWidth: 220

  spacing: 7

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: Icons.forClass(root.appClass)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: Theme.accent
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    elide: Text.ElideRight
    width: Math.min(implicitWidth, root.maxWidth)
  }
}
