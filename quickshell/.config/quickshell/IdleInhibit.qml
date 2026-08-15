// IdleInhibit.qml — "keep this machine awake".
//
// Only the flag lives here. The actual IdleInhibitor object has to be attached
// to a window, so it is instantiated in Bar.qml and follows this.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  property bool enabled: false

  function toggle() {
    root.enabled = !root.enabled;
  }
}
