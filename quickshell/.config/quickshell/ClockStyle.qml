pragma Singleton

// ClockStyle.qml — which face the island's clock wears. Changed from the
// control centre's Clock tile, remembered across restarts.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property var skins: [
    {
      id: "led",
      name: "LED"
    },
    {
      id: "amber",
      name: "Amber LED"
    },
    {
      id: "dots",
      name: "Dot matrix"
    },
    {
      id: "vfd",
      name: "VFD"
    },
    {
      id: "plain",
      name: "Plain"
    }
  ]

  property string skin: "led"
  // Every skin but Plain is a "display" with its own date panel beside it.
  readonly property bool retro: root.skin !== "plain"

  // The colour a skin lights itself in; the others use the island's accent.
  function tint(accent) {
    if (root.skin === "amber")
      return "#ffb000";
    if (root.skin === "vfd")
      return "#7dffd9";
    return accent;
  }
  readonly property string name: (root.skins.find(s => s.id === root.skin) ?? root.skins[0]).name

  function next() {
    const i = root.skins.findIndex(s => s.id === root.skin);
    root.skin = root.skins[(i + 1) % root.skins.length].id;
    file.setText(root.skin);
  }

  FileView {
    id: file
    path: Quickshell.cachePath("clock-skin")

    onLoaded: {
      const saved = text().trim();
      if (root.skins.some(s => s.id === saved))
        root.skin = saved;
    }
    onLoadFailed: Qt.callLater(() => file.setText(root.skin))
  }
}
