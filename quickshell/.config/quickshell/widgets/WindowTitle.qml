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

  // What is actually drawn. Changes go through `swap` — fade out, change,
  // fade in — so a new title never snaps in while the pill is still resizing.
  property string shownTitle: title
  property string shownClass: appClass
  readonly property string iconUrl: Icons.themeIconFor(shownClass)

  // Switching windows passes through "no window" for a frame or two; only
  // believe it once it lasts, or the pill would collapse and reopen.
  property bool present: hasWindow

  onHasWindowChanged: {
    if (hasWindow) {
      absent.stop();
      root.present = true;
    } else {
      absent.restart();
    }
  }

  Timer {
    id: absent
    interval: 220
    onTriggered: root.present = false
  }

  onTitleChanged: root.refresh()
  onAppClassChanged: root.refresh()

  function refresh() {
    if (!root.hasWindow)
      return;
    // Same app, new title (a terminal's cwd, a browser tab): just update.
    if (root.appClass === root.shownClass && root.opacity > 0.99 && !swap.running) {
      root.shownTitle = root.title;
      return;
    }
    swap.restart();
  }

  SequentialAnimation {
    id: swap

    NumberAnimation {
      target: root
      property: "opacity"
      to: 0
      duration: 110
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        root.shownTitle = root.title;
        root.shownClass = root.appClass;
      }
    }
    NumberAnimation {
      target: root
      property: "opacity"
      to: 1
      duration: 220
      easing.type: Easing.OutQuad
    }
  }

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
    text: Icons.forClass(root.shownClass)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: Theme.accent
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: root.shownTitle
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    elide: Text.ElideRight
    width: Math.min(implicitWidth, root.maxWidth)
  }
}
