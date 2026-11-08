// Workspaces.qml — live Hyprland workspaces, for one screen.
//
// Each existing workspace is a small dot; the one this screen is showing
// stretches into a pill and takes the accent colour. No numbers, as in the
// bar design. Click to switch, scroll anywhere on the group to cycle.
//
// A bar lists only the workspaces living on its own monitor. Listing all of
// them put the same row on every screen, which says nothing about the screen
// you are looking at — and clicking a pill there dragged you to another
// monitor.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Item {
  id: root

  // The screen this instance's bar is on. Set by Bar.qml; left unset the row
  // falls back to every workspace, which is the right answer for a single
  // monitor and harmless on more.
  property var barScreen: null

  // `var`, not HyprlandMonitor: that type is exported from the private
  // Quickshell.Hyprland._Ipc module, and naming a type QML cannot resolve
  // fails the whole shell, not just this widget.
  readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : null

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  // Switching goes through an explicit Lua dispatch rather than Quickshell's
  // own workspace activate() method. That method still sends `dispatch
  // workspace <n>`, which Hyprland 0.57 rejects outright — it parses every
  // dispatch as Lua now, so the old string form is a syntax error and the
  // click silently did nothing. JSON.stringify quotes and escapes the name.
  function focusWorkspace(ws) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + JSON.stringify(ws.name) + " })");
  }

  // Hyprland reports workspaces in creation order, so sort by id. Negative ids
  // are special workspaces (your SUPER+S scratchpad) — those get their own
  // indicator rather than a slot in the row.
  //
  // `w.monitor` is null for a moment while Hyprland is still filling a newly
  // created workspace in, so compare by name rather than identity and keep
  // nothing that has no monitor yet.
  ScriptModel {
    id: wsModel
    values: Array.from(Hyprland.workspaces.values).filter(w => w.id > 0 && (!root.monitor || (w.monitor && w.monitor.name === root.monitor.name))).sort((a, b) => a.id - b.id)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Repeater {
      model: wsModel

      // The hit target is the full bar height, so the 8px dots stay easy to
      // click.
      delegate: Item {
        id: slot

        required property var modelData
        // `active` is the workspace this screen is currently showing; `focused`
        // is the one the keyboard is in, which is on exactly one screen. Both
        // stretch the dot, but only the focused one takes the full accent — so
        // a glance at the other monitors still tells you where you are.
        readonly property bool active: modelData.active
        readonly property bool focused: modelData.focused
        readonly property bool urgent: modelData.urgent

        implicitWidth: dot.width
        implicitHeight: 18

        Rectangle {
          id: dot

          anchors.verticalCenter: parent.verticalCenter
          width: slot.active ? 22 : 8
          height: 8
          radius: 4
          color: slot.focused ? Theme.accent : slot.urgent ? Theme.crit : slot.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : mouse.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.28)

          Behavior on width {
            NumberAnimation {
              duration: 300
              easing.type: Easing.BezierSpline
              easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
          }
          Behavior on color {
            ColorAnimation {
              duration: 300
            }
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          anchors.leftMargin: -2
          anchors.rightMargin: -2
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: preview.showFor(slot.modelData, slot.mapToItem(null, 0, 0).x)
          onExited: preview.hideSoon()
          onClicked: {
            preview.hideNow();
            root.focusWorkspace(slot.modelData);
          }
        }
      }
    }

  }

  WorkspacePreview {
    id: preview
    barScreen: root.barScreen
    onChosen: ws => root.focusWorkspace(ws)
  }

  // Scrolling walks this screen's own pills, wrapping at the ends. `workspace
  // e+1` would wander onto whatever workspace happens to be next globally, and
  // it acts on the focused monitor — not the one being scrolled on.
  WheelHandler {
    onWheel: event => {
      const list = wsModel.values;
      if (!root.monitor || list.length === 0) {
        // Lua, not `workspace e-1`: Hyprland 0.57 parses a dispatch as Lua and
        // rejects the old string form outright ("')' expected near '1'").
        Hyprland.dispatch(event.angleDelta.y > 0 ? 'hl.dsp.focus({ workspace = "e-1" })' : 'hl.dsp.focus({ workspace = "e+1" })');
        return;
      }

      const current = list.findIndex(w => w.active);
      const step = event.angleDelta.y > 0 ? -1 : 1;
      // No active pill yet: start from whichever end the scroll points at.
      const next = current < 0 ? (step > 0 ? 0 : list.length - 1) : (current + step + list.length) % list.length;
      root.focusWorkspace(list[next]);
    }
  }
}
