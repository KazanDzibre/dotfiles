pragma Singleton

// Sounds.qml — the island's soft UI sounds. Off unless you turn them on (the
// Sounds button in the control center), and that choice survives restarts. Do
// not disturb silences them too.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property bool enabled: false
  property var lastPlayed: ({})

  IpcHandler {
    target: "sounds"

    function toggle(): void {
      root.toggle();
    }

    function play(name: string): void {
      root.play(name);
    }
  }

  FileView {
    id: file
    path: Quickshell.cachePath("sounds.json")

    onLoaded: {
      try {
        root.enabled = JSON.parse(text()).enabled === true;
      } catch (e) {
        root.enabled = false;
      }
    }
    // Same as Spotlight's usage file: create it so it doesn't warn every start.
    onLoadFailed: Qt.callLater(() => file.setText(JSON.stringify({
          enabled: false
        })))
  }

  function toggle() {
    root.enabled = !root.enabled;
    file.setText(JSON.stringify({
      enabled: root.enabled
    }));
    root.play("open");
  }

  function play(name) {
    if (!root.enabled || Notifications.doNotDisturb)
      return;
    // Several things can happen at once; only one of each should be heard.
    const now = Date.now();
    if (now - (root.lastPlayed[name] ?? 0) < 180)
      return;
    root.lastPlayed[name] = now;
    Quickshell.execDetached(["pw-play", "--volume", "0.6", Quickshell.shellPath("sounds/" + name + ".ogg")]);
  }
}
