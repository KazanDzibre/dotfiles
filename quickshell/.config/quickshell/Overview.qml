pragma Singleton

// Overview.qml — opens the workspace overview (widgets/WorkspaceOverview.qml)
// on the screen you're on. Bound to SUPER+Tab in hyprland.lua.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  signal toggleRequested(string screenName)

  function toggle() {
    root.toggleRequested(Hyprland.focusedMonitor?.name ?? "");
  }

  IpcHandler {
    target: "overview"

    function toggle(): void {
      root.toggle();
    }
  }

  GlobalShortcut {
    appid: "quickshell"
    name: "overview"
    description: "Show every workspace side by side"
    onPressed: root.toggle()
  }
}
