// Workspaces.qml — live Hyprland workspaces, for one screen.
//
// Each existing workspace is a small dot in the colour of its main app; the one
// this screen is showing is covered by a pill, and the focused one takes the
// accent colour. A dot pulses when a window there wants attention. No numbers,
// as in the bar design. Click to switch, scroll anywhere on the group to cycle.
//
// The pill is one rectangle whose two edges are driven by separate springs. The
// edge in the direction of travel is stiff and arrives first; the trailing edge
// is soft and catches up, so the pill stretches across the gap and then snaps
// back with a little overshoot. A fainter ghost lags further behind, which is
// what smears a quick run of switches. Both spring sets are tunable below.
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

  // The slot of the workspace this screen is showing. `rep.count` is read so the
  // binding re-runs once the Repeater has actually built the delegate.
  readonly property Item activeSlot: {
    rep.count;
    const i = wsModel.values.findIndex(w => w.active);
    return i >= 0 ? rep.itemAt(i) : null;
  }

  // Where each edge of the pill wants to be, in this item's coordinates.
  readonly property real targetLeft: activeSlot ? row.x + activeSlot.x : 0
  readonly property real targetRight: activeSlot ? row.x + activeSlot.x + activeSlot.width : 0
  property real previousCentre: -1
  readonly property bool movingRight: (targetLeft + targetRight) / 2 >= previousCentre

  onTargetLeftChanged: Qt.callLater(() => root.previousCentre = (root.targetLeft + root.targetRight) / 2)

  // Stiffness/damping of the two edges. Qt's SpringAnimation: higher spring is
  // snappier, lower damping rings longer.
  readonly property real leadSpring: 9.0
  readonly property real leadDamping: 0.32
  readonly property real tailSpring: 3.8
  readonly property real tailDamping: 0.26

  // No spring on the first placement, or the pill would fly in from x = 0 when
  // the bar starts.
  property bool ready: false
  Timer {
    running: true
    interval: 600
    onTriggered: root.ready = true
  }

  property real edgeLeft: targetLeft
  property real edgeRight: targetRight

  Behavior on edgeLeft {
    enabled: root.ready && root.activeSlot !== null
    SpringAnimation {
      spring: root.movingRight ? root.tailSpring : root.leadSpring
      damping: root.movingRight ? root.tailDamping : root.leadDamping
      epsilon: 0.2
    }
  }
  Behavior on edgeRight {
    enabled: root.ready && root.activeSlot !== null
    SpringAnimation {
      spring: root.movingRight ? root.leadSpring : root.tailSpring
      damping: root.movingRight ? root.leadDamping : root.tailDamping
      epsilon: 0.2
    }
  }

  // The ghost: the same edges again, but eased slowly instead of sprung.
  property real ghostLeft: edgeLeft
  property real ghostRight: edgeRight
  Behavior on ghostLeft {
    enabled: root.ready
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }
  Behavior on ghostRight {
    enabled: root.ready
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

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
      id: rep
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

        // The app with the most windows here; the first one found wins a tie.
        readonly property string mainApp: {
          const counts = {};
          let best = "";
          for (const t of Array.from(Hyprland.toplevels.values)) {
            if (!t.workspace || t.workspace.id !== modelData.id)
              continue;
            const cls = (t.wayland ? t.wayland.appId : "") || (t.lastIpcObject ? t.lastIpcObject.class : "") || "";
            if (!cls)
              continue;
            counts[cls] = (counts[cls] ?? 0) + 1;
            if (!best || counts[cls] > counts[best])
              best = cls;
          }
          return best;
        }
        readonly property string appHex: AppColors.colorFor(mainApp)

        function tinted(alpha) {
          const c = Qt.color(appHex);
          return Qt.rgba(c.r, c.g, c.b, alpha);
        }

        // The active slot is wider so the pill has room; the dot itself stays
        // a dot and the pill, drawn above, does the stretching.
        implicitWidth: slot.active ? 22 : 8
        implicitHeight: 18

        Behavior on implicitWidth {
          NumberAnimation {
            duration: 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
          }
        }

        readonly property color tone: slot.urgent ? Theme.crit : slot.focused ? Theme.accent : slot.appHex ? slot.tinted(mouse.containsMouse ? 1 : slot.active ? 0.95 : 0.75) : slot.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : mouse.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.28)

        Rectangle {
          id: dot

          anchors.centerIn: parent
          width: 8
          height: 8
          radius: 4
          color: slot.tone

          SequentialAnimation on scale {
            running: slot.urgent
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
              to: 1.45
              duration: 520
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 1
              duration: 520
              easing.type: Easing.InOutSine
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

  Rectangle {
    id: ghost
    // Only while the pill is actually moving; at rest it sits exactly under the
    // pill and anything it adds there reads as a halo.
    visible: root.activeSlot !== null && (Math.abs(root.ghostLeft - root.edgeLeft) > 1.5 || Math.abs(root.ghostRight - root.edgeRight) > 1.5)
    y: (root.height - height) / 2
    x: Math.min(root.ghostLeft, root.ghostRight)
    width: Math.max(8, Math.abs(root.ghostRight - root.ghostLeft))
    height: 8
    radius: 4
    color: pill.color
    opacity: 0.25
  }

  // Flip to bring the glow back.
  readonly property bool glow: false

  // Glow: two wider, fainter copies of the pill's footprint stacked under it.
  // Cheaper than blurring a layer on every frame of a spring, and the bar is
  // always on screen.
  Rectangle {
    visible: root.glow && root.activeSlot !== null
    x: pill.x - 7
    y: (root.height - height) / 2
    width: pill.width + 14
    height: 22
    radius: 11
    color: pill.color
    opacity: 0.05
  }
  Rectangle {
    visible: root.glow && root.activeSlot !== null
    x: pill.x - 3.5
    y: (root.height - height) / 2
    width: pill.width + 7
    height: 15
    radius: 7.5
    color: pill.color
    opacity: 0.11
  }

  Rectangle {
    id: pill
    visible: root.activeSlot !== null
    y: (root.height - height) / 2
    // Edges can cross for a frame while the springs overshoot; sort them so the
    // width never goes negative, and never shrink below a dot.
    x: Math.min(root.edgeLeft, root.edgeRight)
    width: Math.max(8, Math.abs(root.edgeRight - root.edgeLeft))
    height: 8
    radius: 4
    color: root.activeSlot ? root.activeSlot.tone : Theme.accent

    Behavior on color {
      ColorAnimation {
        duration: 300
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
