pragma Singleton

// IslandTerm.qml — the island turning into a terminal and back (Super+`).
//
// hypr/.local/bin/island-term makes sure the terminal exists, then calls
// `qs ipc call islandterm open <address>` or `close <address>`. The terminal
// is a plain black Alacritty that Hyprland parks on special:term between
// uses, at exactly the rectangle the island grows into.
//
// Opening: the island grows from its pill into that rectangle (DynamicIsland's
// "term" mode: flat black, the terminal's corners, no rim). The terminal is
// moved in underneath it, then the island steps aside in a single frame,
// leaving the terminal where it was: same black, same shape, so the island
// simply *is* the terminal now. Closing runs backwards: the island steps back
// in over the terminal, the terminal is parked, and the island shrinks back
// to its pill.
//
// While it's open, a click anywhere else puts it away (the catcher below),
// and so does switching workspace.
//
// The size and spot must match the island-term window rule in hyprland.lua
// and hyprland.conf: 720x430, its top edge on the island's top edge.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
  id: root

  readonly property int width: 720
  readonly property int height: 430
  readonly property int radius: 22

  // The island is grown into the terminal's rectangle.
  property bool covering: false
  // The terminal is on screen and the island has stepped aside for it.
  property bool shown: false
  // The screen it happens on (each screen has its own island).
  property string screenName: ""
  property bool busy: false
  property string address: ""

  // How long the island takes to grow most of the way into the rectangle
  // (DynamicIsland.morphMs is 620 with an overshoot).
  readonly property int growMs: 560
  // Time for Hyprland to put the terminal in place under the island, or take
  // it away: long enough for its fade (fadeIn/fadeOut in hyprland.lua) to
  // finish, or the wallpaper shows through it for a moment.
  readonly property int placeMs: 240

  function moveWindow(workspace) {
    const win = "address:" + root.address;
    const ws = typeof workspace === "number" ? String(workspace) : JSON.stringify(workspace);
    HyprCompat.dispatch("movetoworkspacesilent " + workspace + "," + win, "hl.dsp.window.move({ workspace = " + ws + ", follow = false, window = \"" + win + "\" })");
  }

  function open(address) {
    if (busy || address === "")
      return;
    busy = true;
    root.address = address;
    screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    shown = false;
    covering = true;
    openPlace.restart();
  }

  function close() {
    if (busy || !shown)
      return;
    busy = true;
    // The island back over the terminal, already at its size, in one frame.
    shown = false;
    closePark.restart();
  }

  // Grown: bring the terminal in underneath and focus it.
  Timer {
    id: openPlace
    interval: root.growMs
    onTriggered: {
      const ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
      root.moveWindow(ws);
      HyprCompat.dispatch("focuswindow address:" + root.address, "hl.dsp.focus({ window = \"address:" + root.address + "\" })");
      openReveal.restart();
    }
  }

  // In place: the island steps aside.
  Timer {
    id: openReveal
    interval: root.placeMs
    onTriggered: {
      root.shown = true;
      root.busy = false;
    }
  }

  // The island is over it again: park the terminal.
  Timer {
    id: closePark
    interval: 40
    onTriggered: {
      root.moveWindow("special:term");
      closeShrink.restart();
    }
  }

  // Parked: the island shrinks back to its pill.
  Timer {
    id: closeShrink
    interval: root.placeMs
    onTriggered: {
      root.covering = false;
      closeDone.restart();
    }
  }

  Timer {
    id: closeDone
    interval: 650
    onTriggered: root.busy = false
  }

  // The terminal itself closing (Super+Shift+Q, `exit`, a kill) while the
  // island is grown into it: nothing is left to park, so the island just
  // shrinks back to its pill. Without this it stayed a black rectangle until
  // the next click.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "closewindow" || root.address === "" || !(root.covering || root.shown))
        return;
      const closed = event.data.replace(/^0x/, "");
      if (closed !== root.address.replace(/^0x/, ""))
        return;
      openPlace.stop();
      openReveal.stop();
      closePark.stop();
      root.address = "";
      root.busy = true;
      root.shown = false;
      closeShrink.restart();
    }
  }

  // Leaving the workspace puts it away too, without the motion: it isn't on
  // screen to morph any more.
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      if (!root.shown || root.busy)
        return;
      root.moveWindow("special:term");
      root.shown = false;
      root.covering = false;
    }
  }

  // A click anywhere but the terminal puts it away. A see-through layer over
  // the screen, with a hole where the terminal is, so the terminal itself
  // still takes the pointer. It also stops hovering another window from
  // stealing focus (focus follows the mouse) while the terminal is open.
  PanelWindow {
    id: catcher

    screen: Quickshell.screens.find(s => s.name === root.screenName) ?? null
    visible: root.shown && screen !== null
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell:island-term-catcher"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property real holeX: (width - root.width) / 2
    readonly property real holeY: Math.round((Theme.barHeight - 28) / 2)

    mask: Region {
      x: 0
      y: 0
      width: catcher.width
      height: catcher.height

      Region {
        intersection: Intersection.Subtract
        x: catcher.holeX
        y: catcher.holeY
        width: root.width
        height: root.height
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: root.close()
    }
  }

  IpcHandler {
    target: "islandterm"

    function open(address: string): void {
      root.open(address);
    }
    function close(address: string): void {
      root.close();
    }
  }
}
