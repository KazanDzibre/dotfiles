// WindowTitle.qml — icon + title of the focused window.
//
// Sourced from the Wayland toplevel manager, not Hyprland.activeToplevel: the
// latter only populates once Hyprland emits an activewindow event, so after a
// shell restart it stays null until you switch windows.
//
// Truncates rather than pushing the centre clock off-centre; at 1280 logical
// pixels wide that matters.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs

Row {
  id: root

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string title: toplevel ? toplevel.title : ""
  readonly property string appClass: toplevel ? (toplevel.appId ?? "") : ""
  readonly property bool hasWindow: title.length > 0
  readonly property string iconUrl: Icons.themeIconFor(appClass)

  property int maxWidth: 160

  spacing: 7

  IconImage {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.iconUrl !== ""
    source: root.iconUrl
    implicitSize: Theme.iconSize
    asynchronous: true
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.iconUrl === ""
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
