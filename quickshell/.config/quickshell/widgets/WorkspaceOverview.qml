// WorkspaceOverview.qml — every workspace on this screen side by side, as live
// miniatures, over a frosted copy of the desktop. SUPER+Tab (Overview.qml).
//
// Click a workspace and it zooms up to fill the screen as you land on it.
// Type to find a window (Enter jumps to the first match), hover a window to
// close it, drag a window onto another workspace to move it there, or onto
// the "+" slot for a new one. Esc or SUPER+Tab again closes it.
//
// Window images come from ScreencopyView, refreshed every second while open,
// the same way the workspace hover preview does it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

PanelWindow {
  id: root

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  WlrLayershell.namespace: "quickshell:overview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  focusable: shown

  // Mapped while open and while it fades or zooms away.
  property bool shown: false
  visible: shown || scrim.opacity > 0.01 || zoomIndex >= 0

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property color ink: "#f4efe2"
  readonly property color inkDim: Qt.rgba(0.96, 0.94, 0.89, 0.6)
  readonly property var springCurve: [0.34, 1.32, 0.5, 1, 1, 1]
  readonly property var zoomCurve: [0.2, 0.8, 0.2, 1, 1, 1]

  // ------------------------------------------------------------------ data
  readonly property var workspaces: Array.from(Hyprland.workspaces.values).filter(w => w.id > 0 && (!root.monitor || (w.monitor && w.monitor.name === root.monitor.name))).sort((a, b) => a.id - b.id)

  // One slot per workspace, then the "+" one.
  readonly property var slots: workspaces.map(w => ({
        ws: w,
        isNew: false
      })).concat([{
        ws: null,
        isNew: true
      }])

  readonly property int nextId: Array.from(Hyprland.workspaces.values).reduce((m, w) => Math.max(m, w.id), 0) + 1

  function windowsOf(ws) {
    if (!ws)
      return [];
    return Array.from(Hyprland.toplevels.values).filter(t => t.workspace && t.workspace.id === ws.id && t.wayland);
  }

  function classOf(t) {
    return (t.wayland ? t.wayland.appId : "") || (t.lastIpcObject ? t.lastIpcObject.class : "") || "";
  }

  function mainApp(ws) {
    const counts = {};
    let best = "";
    for (const t of root.windowsOf(ws)) {
      const cls = root.classOf(t);
      if (!cls)
        continue;
      counts[cls] = (counts[cls] ?? 0) + 1;
      if (!best || counts[cls] > counts[best])
        best = cls;
    }
    return best;
  }

  function appName(cls) {
    if (!cls)
      return "Empty";
    const entry = DesktopEntries.heuristicLookup(cls);
    if (entry)
      return entry.name;
    const last = cls.split(".").pop();
    return last.charAt(0).toUpperCase() + last.slice(1);
  }

  property string query: ""
  readonly property string q: query.trim().toLowerCase()

  function matches(t) {
    if (!root.q)
      return true;
    const title = (t.wayland ? t.wayland.title : t.title) || "";
    return title.toLowerCase().includes(root.q) || root.classOf(t).toLowerCase().includes(root.q);
  }

  readonly property var firstMatch: {
    if (!q)
      return null;
    for (const s of slots) {
      const hit = root.windowsOf(s.ws).find(t => root.matches(t));
      if (hit)
        return hit;
    }
    return null;
  }

  // ---------------------------------------------------------------- layout
  readonly property int gap: 24
  readonly property real cardW: Math.min(250, (width - 160 - (slots.length - 1) * gap) / slots.length)
  readonly property real cardH: height > 0 ? cardW * height / width : cardW * 0.625
  readonly property real rowLeft: (width - (slots.length * cardW + (slots.length - 1) * gap)) / 2
  readonly property real rowTop: (height - cardH) / 2 - 10
  readonly property real factor: width > 0 ? cardW / width : 0.2

  function slotX(i) {
    return root.rowLeft + i * (root.cardW + root.gap);
  }

  property int selected: 0
  property int zoomIndex: -1

  // ------------------------------------------------------------- open/close
  function open() {
    Hyprland.refreshToplevels();
    root.query = "";
    field.text = "";
    root.zoomIndex = -1;
    const active = root.workspaces.findIndex(w => w.active);
    root.selected = Math.max(0, active);
    root.shown = true;
    focusRetry.attempts = 0;
    focusRetry.restart();
  }

  function close() {
    root.shown = false;
  }

  Connections {
    target: Overview
    function onToggleRequested(screenName) {
      if (!root.screen || root.screen.name !== screenName)
        return;
      if (root.shown)
        root.close();
      else
        root.open();
    }
  }

  // The surface only gets the keyboard once mapped with focus; keep asking.
  Timer {
    id: focusRetry
    property int attempts: 0
    interval: 40
    repeat: true
    onTriggered: {
      if (!root.shown || field.activeFocus || attempts > 25) {
        stop();
        return;
      }
      attempts++;
      field.forceActiveFocus();
    }
  }

  // ---------------------------------------------------------------- actions
  function dispatchFocus(id) {
    HyprCompat.dispatch("workspace " + id, "hl.dsp.focus({ workspace = " + JSON.stringify(String(id)) + " })");
  }

  // Go to a workspace: switch underneath straight away, while its card grows
  // to fill the screen, then let the overview go.
  function go(i) {
    const slot = root.slots[i];
    if (!slot)
      return;
    if (slot.isNew) {
      root.dispatchFocus(root.nextId);
      root.close();
      return;
    }
    root.dispatchFocus(slot.ws.name);
    root.zoomIndex = i;
    root.shown = false;
    zoomDone.restart();
  }

  Timer {
    id: zoomDone
    interval: 600
    onTriggered: root.zoomIndex = -1
  }

  function goToWindow(t) {
    const i = root.slots.findIndex(s => s.ws && t.workspace && s.ws.id === t.workspace.id);
    if (t.wayland)
      t.wayland.activate();
    if (i >= 0) {
      root.zoomIndex = i;
      root.shown = false;
      zoomDone.restart();
    } else {
      root.close();
    }
  }

  function address(t) {
    const a = String(t.address ?? "");
    return a.startsWith("0x") ? a : "0x" + a;
  }

  function moveWindow(t, slot) {
    const id = slot.isNew ? root.nextId : slot.ws.id;
    if (!slot.isNew && t.workspace && t.workspace.id === id)
      return;
    const addr = root.address(t);
    HyprCompat.dispatch("movetoworkspacesilent " + id + ",address:" + addr, "hl.dsp.window.move({ workspace = " + id + ", follow = false, window = \"address:" + addr + "\" })");
    refreshSoon.restart();
  }

  Timer {
    id: refreshSoon
    interval: 150
    onTriggered: Hyprland.refreshToplevels()
  }

  // ----------------------------------------------------------------- drawing
  // The frosted backdrop. Its blur is Hyprland's (the layer rule for
  // quickshell:overview); this only darkens it.
  Rectangle {
    id: scrim
    anchors.fill: parent
    color: Qt.rgba(0.05, 0.035, 0.025, 0.58)
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: root.shown ? 260 : 380
        easing.type: Easing.OutCubic
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  // Search, and the hint underneath the row.
  Item {
    anchors.fill: parent
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: root.shown ? 300 : 160
      }
    }

    Rectangle {
      x: (parent.width - width) / 2
      y: root.rowTop - 96
      width: 440
      height: 44
      radius: 22
      color: Qt.rgba(0.02, 0.016, 0.012, 0.88)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.1)

      Text {
        id: searchGlyph
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.search
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: Theme.accent
      }

      TextInput {
        id: field
        anchors.left: searchGlyph.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        color: root.ink
        selectionColor: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 2
        clip: true

        onTextChanged: root.query = text

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            root.close();
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.firstMatch)
              root.goToWindow(root.firstMatch);
            else
              root.go(root.selected);
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.selected = (root.selected + 1) % root.slots.length;
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
            root.selected = (root.selected - 1 + root.slots.length) % root.slots.length;
          } else {
            return;
          }
          event.accepted = true;
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: field.text.length === 0
          text: "Type to find a window"
          font: field.font
          color: root.inkDim
        }
      }
    }

    Text {
      x: 0
      width: parent.width
      y: root.rowTop + root.cardH + 64
      horizontalAlignment: Text.AlignHCenter
      text: "←→ choose · Enter go · type to find · drag a window to move it · Esc close"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize + 1
      color: root.inkDim
    }
  }

  // The row of workspaces.
  Repeater {
    model: root.slots

    delegate: Item {
      id: card

      required property var modelData
      required property int index

      readonly property var ws: modelData.ws
      readonly property bool isNew: modelData.isNew
      readonly property var wins: root.visible ? root.windowsOf(ws) : []
      readonly property bool anyMatch: !root.q || wins.some(t => root.matches(t))
      readonly property bool zooming: root.zoomIndex === index
      readonly property bool dropTarget: dragGhost.visible && dragGhost.overIndex === index
      readonly property string app: isNew ? "" : root.mainApp(ws)

      x: root.slotX(index)
      y: root.rowTop
      width: root.cardW
      height: root.cardH + 38
      z: zooming ? 10 : 1

      // In: rises and settles with the backdrop. Away: fades, except the one
      // you chose, which grows to fill the screen.
      opacity: zooming ? 1 : root.shown ? (anyMatch || isNew ? 1 : 0.4) : 0
      scale: zooming ? root.width / root.cardW : root.shown ? (dropTarget ? 1.04 : 1) : 0.9
      transformOrigin: Item.Center
      transform: Translate {
        x: card.zooming ? root.width / 2 - (card.x + card.width / 2) : 0
        y: card.zooming ? root.height / 2 - (card.y + root.cardH / 2) - (card.height - root.cardH) / 2 * (root.width / root.cardW) + (card.height - root.cardH) / 2 : 0

        Behavior on x {
          NumberAnimation {
            duration: 560
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.zoomCurve
          }
        }
        Behavior on y {
          NumberAnimation {
            duration: 560
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.zoomCurve
          }
        }
      }

      Behavior on opacity {
        NumberAnimation {
          duration: card.zooming ? 0 : root.shown ? 260 + card.index * 30 : 180
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: card.zooming ? 560 : 520
          easing.type: Easing.BezierSpline
          easing.bezierCurve: card.zooming ? root.zoomCurve : root.springCurve
        }
      }

      ClippingRectangle {
        id: thumb
        width: parent.width
        height: root.cardH
        radius: card.zooming ? 0 : 12
        color: card.isNew ? Qt.rgba(1, 1, 1, 0.05) : Theme.base
        border.width: card.isNew ? 0 : (root.selected === card.index || card.dropTarget) && root.shown ? 2 : 1
        border.color: (root.selected === card.index || card.dropTarget) && root.shown ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)

        Behavior on radius {
          NumberAnimation {
            duration: 500
          }
        }

        Image {
          anchors.fill: parent
          visible: !card.isNew
          source: Wallpaper.current ? "file://" + Wallpaper.thumbFor(Wallpaper.current) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 720
        }

        // "+": a dashed outline, drawn as short segments.
        Repeater {
          model: card.isNew ? 4 : 0

          delegate: Rectangle {
            required property int index
            readonly property bool horizontal: index < 2
            x: index === 3 ? thumb.width - 1.5 : 0
            y: index === 1 ? thumb.height - 1.5 : 0
            width: horizontal ? thumb.width : 1.5
            height: horizontal ? 1.5 : thumb.height
            color: card.dropTarget ? Theme.accent : Qt.rgba(0.96, 0.94, 0.89, 0.35)
          }
        }

        Text {
          anchors.centerIn: parent
          visible: card.isNew
          text: "+"
          font.family: Theme.fontFamily
          font.pixelSize: 30
          color: card.dropTarget ? Theme.accent : root.inkDim
        }

        Repeater {
          model: card.wins

          delegate: Rectangle {
            id: win

            required property var modelData
            readonly property var info: modelData.lastIpcObject
            readonly property bool lit: root.matches(modelData)

            x: info && info.at && root.monitor ? (info.at[0] - root.monitor.x) * root.factor : 0
            y: info && info.at && root.monitor ? (info.at[1] - root.monitor.y) * root.factor : 0
            width: info && info.size ? info.size[0] * root.factor : thumb.width
            height: info && info.size ? info.size[1] * root.factor : thumb.height
            radius: 4
            color: Theme.base
            border.width: root.q && lit ? 1.5 : 0
            border.color: Theme.accent
            opacity: lit ? (dragGhost.source === modelData ? 0.3 : 1) : 0.25

            Behavior on opacity {
              NumberAnimation {
                duration: 180
              }
            }

            IconImage {
              anchors.centerIn: parent
              visible: !capture.hasContent
              implicitSize: Math.min(28, parent.height * 0.5)
              source: Icons.themeIconFor(root.classOf(win.modelData))
            }

            ScreencopyView {
              id: capture
              anchors.fill: parent
              anchors.margins: win.border.width
              captureSource: win.modelData.wayland
              live: false
              constraintSize: Qt.size(Math.max(1, Math.round(win.width * 2)), Math.max(1, Math.round(win.height * 2)))
              Component.onCompleted: captureFrame()
            }

            Timer {
              running: root.shown
              repeat: true
              interval: 1000
              onTriggered: capture.captureFrame()
            }

            // Click to go to the window, drag to move it to another workspace.
            MouseArea {
              id: winArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
              property point start

              onPressed: event => start = Qt.point(event.x, event.y)
              onPositionChanged: event => {
                if (!pressed)
                  return;
                if (!dragGhost.visible && Math.hypot(event.x - start.x, event.y - start.y) > 6)
                  dragGhost.begin(win.modelData, win);
                if (dragGhost.visible)
                  dragGhost.follow(mapToItem(null, event.x, event.y));
              }
              onReleased: {
                if (dragGhost.visible)
                  dragGhost.drop();
              }
              onClicked: {
                if (!dragGhost.dropped)
                  root.goToWindow(win.modelData);
                dragGhost.dropped = false;
              }
            }

            // Close, on hover.
            Rectangle {
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 3
              width: 18
              height: 18
              radius: 9
              visible: (winArea.containsMouse || closeArea.containsMouse) && !dragGhost.visible && root.shown
              color: closeArea.containsMouse ? "#f0808f" : Qt.rgba(0.02, 0.016, 0.012, 0.85)

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 9
                font.bold: true
                color: closeArea.containsMouse ? "#140f08" : root.ink
              }

              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (win.modelData.wayland)
                    win.modelData.wayland.close();
                  refreshSoon.restart();
                }
              }
            }
          }
        }
      }

      // Clicking the card's empty space (or the "+") goes there.
      MouseArea {
        z: -1
        width: thumb.width
        height: thumb.height
        cursorShape: Qt.PointingHandCursor
        onClicked: root.go(card.index)
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cardH + 14
        spacing: 7
        opacity: card.zooming ? 0 : 1

        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          visible: !card.isNew
          width: 7
          height: 7
          radius: 3.5
          color: AppColors.colorFor(card.app) || Qt.rgba(0.96, 0.94, 0.89, 0.4)
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !card.isNew
          text: card.ws ? card.ws.name : ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          color: root.ink
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: card.isNew ? "New workspace" : root.appName(card.app)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: root.inkDim
        }
      }
    }
  }

  // What follows the pointer while a window is dragged.
  Rectangle {
    id: dragGhost

    property var source: null
    property int overIndex: -1
    property bool dropped: false

    visible: source !== null
    z: 20
    width: 120
    height: 76
    radius: 8
    color: Qt.rgba(0.02, 0.016, 0.012, 0.9)
    border.width: 1.5
    border.color: Theme.accent

    IconImage {
      anchors.centerIn: parent
      implicitSize: 30
      source: dragGhost.source ? Icons.themeIconFor(root.classOf(dragGhost.source)) : ""
    }

    function begin(t, item) {
      dragGhost.source = t;
      dragGhost.dropped = false;
    }

    function follow(p) {
      dragGhost.x = p.x - width / 2;
      dragGhost.y = p.y - height / 2;
      let over = -1;
      for (let i = 0; i < root.slots.length; i++) {
        const x0 = root.slotX(i);
        if (p.x >= x0 && p.x <= x0 + root.cardW && p.y >= root.rowTop && p.y <= root.rowTop + root.cardH)
          over = i;
      }
      dragGhost.overIndex = over;
    }

    function drop() {
      if (dragGhost.overIndex >= 0)
        root.moveWindow(dragGhost.source, root.slots[dragGhost.overIndex]);
      dragGhost.source = null;
      dragGhost.overIndex = -1;
      // The click that ends a drag mustn't also count as "go to this window".
      dragGhost.dropped = true;
    }
  }
}
