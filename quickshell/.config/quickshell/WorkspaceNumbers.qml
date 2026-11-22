pragma Singleton

// WorkspaceNumbers.qml — SUPER+N: the bar's workspace dots widen into small
// pills with each workspace's number on them, so you can tell which number a
// coloured dot is. SUPER+N again puts them back to dots.
//
// widgets/Workspaces.qml reads `shown`. Bound in hyprland.lua and
// hyprland.conf; also `qs ipc call workspacenumbers toggle`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
  id: root

  property bool shown: false

  function toggle() {
    root.shown = !root.shown;
  }

  IpcHandler {
    target: "workspacenumbers"

    function toggle(): void {
      root.toggle();
    }
    function show(): void {
      root.shown = true;
    }
    function hide(): void {
      root.shown = false;
    }
  }

  GlobalShortcut {
    appid: "quickshell"
    name: "workspaceNumbers"
    description: "Show the workspace numbers on the bar's dots"
    onPressed: root.toggle()
  }
}
