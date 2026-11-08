// DynamicIsland.qml — the black pill in the middle of the bar.
//
// It is its own layer-shell window, not part of the bar, because it has to grow
// well past the bar's 34px: the media player it opens into is ~150px tall. The
// window is generous and transparent; only the island itself takes input (see
// `mask`).
//
// What it shows is one "mode" at a time, picked in priority order:
//   1. a moment from Moments.qml (volume, a toggle, a notification, a screenshot…)
//   2. the expanded media player, if you opened it
//   3. the AI answering, updates installing
//   4. music playing (compact), the focus timer
//   5. the clock
// Every mode is a Layer with its own size; the island springs to that size and
// the layers cross-fade (old one shrinks away, new one grows in a beat later).
//
// Alongside it: a round bubble for the focus timer when music already has the
// island, and a breathing dot while keep awake is on.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

PanelWindow {
  id: root

  // ----------------------------------------------------------------- window
  anchors.top: true
  implicitWidth: 600
  // Tall enough for the biggest card; only the island itself takes input.
  implicitHeight: 480
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  WlrLayershell.namespace: "quickshell:island"
  WlrLayershell.layer: WlrLayer.Top
  // Keyboard only while the search box is open.
  WlrLayershell.keyboardFocus: mode === "search" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  focusable: mode === "search"

  // Bound field by field: a Region given just `item` didn't follow the island
  // as it resized, which left it unclickable.
  mask: Region {
    x: hit.x
    y: hit.y
    width: hit.width
    height: hit.height
  }

  // ------------------------------------------------------------------ look
  // The island stays black in light mode too, so it carries its own inks
  // rather than Theme.fg (which is dark in light mode).
  readonly property color ink: "#f4efe2"
  readonly property color inkDim: Qt.rgba(0.96, 0.94, 0.89, 0.55)
  readonly property color hot: Qt.hsva(Theme.accentHue, Math.min(1.0, Theme.accentRaw.hsvSaturation * 1.15), Math.max(0.8, Theme.accentRaw.hsvValue), 1.0)
  readonly property color good: "#8ad79a"
  readonly property int compactH: 28

  // The mockup's curves, verbatim: CSS cubic-bezier(.34,1.32,.5,1) over 620ms
  // for the island's shape, (.34,1.4,.5,1) for content arriving.
  readonly property var shapeCurve: [0.34, 1.32, 0.5, 1, 1, 1]
  readonly property var popCurve: [0.34, 1.4, 0.5, 1, 1, 1]
  readonly property int morphMs: 620

  // ------------------------------------------------------------------ state
  // Which big card is open, if any: "player", "today", "inbox" or "search".
  property string view: ""

  // Cover colour when the track has one, otherwise the theme's accent.
  property color tint: Media.hasCoverTint ? Media.coverTint : hot
  Behavior on tint {
    ColorAnimation {
      duration: 700
    }
  }

  // True once the island has finished morphing into the current mode. Typing
  // in the search resizes the island on every key; those need to be quick, not
  // a full spring each time.
  property bool settled: false
  Timer {
    id: settleTimer
    interval: root.morphMs + 40
    onTriggered: root.settled = true
  }

  // ----------------------------------------------------------------- search
  property string query: ""
  property int selected: 0
  readonly property var results: view === "search" ? Spotlight.search(query) : []
  onResultsChanged: selected = 0

  function openSearch() {
    Moments.dismiss();
    root.query = "";
    root.lastPointer = Qt.point(-1, -1);
    searchField.text = "";
    root.view = "search";
    focusRetry.attempts = 0;
    focusRetry.restart();
  }

  property point lastPointer: Qt.point(-1, -1)

  function pointerMoved(x, y) {
    const first = root.lastPointer.x < 0;
    const moved = x !== root.lastPointer.x || y !== root.lastPointer.y;
    root.lastPointer = Qt.point(x, y);
    return !first && moved;
  }

  function runSelected() {
    const item = root.results[root.selected];
    if (!item)
      return;
    root.view = "";
    Spotlight.run(item);
  }

  // The surface only gets the keyboard once mapped with focus; keep asking.
  Timer {
    id: focusRetry
    property int attempts: 0
    interval: 40
    repeat: true
    onTriggered: {
      if (root.view !== "search" || searchField.activeFocus || attempts > 25) {
        stop();
        return;
      }
      attempts++;
      searchField.forceActiveFocus();
    }
  }

  Connections {
    target: Spotlight
    function onToggleRequested(screenName) {
      if (screenName !== root.screenName())
        return;
      if (root.view === "search")
        root.view = "";
      else
        root.openSearch();
    }
  }

  // --------------------------------------------------------------- gestures
  property real swipeTotal: 0
  property real dayTotal: 0
  property bool swipeLocked: false
  property int dayOffset: 0
  property bool volumeShown: false
  property real nudge: 0

  onViewChanged: {
    if (view !== "today")
      dayOffset = 0;
    if (view !== "inbox")
      openGroup = "";
  }

  Timer {
    id: gestureIdle
    interval: 280
    onTriggered: {
      root.swipeTotal = 0;
      root.dayTotal = 0;
      root.swipeLocked = false;
    }
  }

  Timer {
    id: volumeHide
    interval: 1300
    onTriggered: root.volumeShown = false
  }

  // A small shove in the direction of the skip.
  SequentialAnimation {
    id: nudgeAnim
    property real amount: 8
    NumberAnimation {
      target: root
      property: "nudge"
      to: nudgeAnim.amount
      duration: 110
      easing.type: Easing.OutQuad
    }
    NumberAnimation {
      target: root
      property: "nudge"
      to: 0
      duration: 460
      easing.type: Easing.BezierSpline
      easing.bezierCurve: root.popCurve
    }
  }

  // Up and down is volume, sideways skips, on anything showing music. On the
  // clock and Today card, up and down walks through the days. Trackpads send
  // many tiny events and wheels a few big ones, so both add up to a threshold.
  function scrolled(wheel) {
    const dx = wheel.angleDelta.x;
    const dy = wheel.angleDelta.y;
    gestureIdle.restart();

    const onMusic = root.mode === "player" || root.mode === "music" || (root.mode === "level" && root.musicOn);
    if (onMusic && Media.active) {
      if (Math.abs(dx) > Math.abs(dy)) {
        root.swipeTotal += dx;
        if (!root.swipeLocked && Math.abs(root.swipeTotal) >= 240) {
          root.swipeLocked = true;
          const next = root.swipeTotal < 0;
          nudgeAnim.amount = next ? -8 : 8;
          nudgeAnim.restart();
          if (next && Media.active.canGoNext)
            Media.active.next();
          else if (!next && Media.active.canGoPrevious)
            Media.active.previous();
        }
      } else if (Moments.sink && Moments.sink.audio) {
        const audio = Moments.sink.audio;
        audio.volume = Math.max(0, Math.min(1, audio.volume + dy / 120 * 0.03));
        root.volumeShown = true;
        volumeHide.restart();
      }
      return;
    }

    if (root.mode === "clock" || root.mode === "today") {
      root.dayTotal += dy;
      if (Math.abs(root.dayTotal) >= 120) {
        const step = root.dayTotal > 0 ? -1 : 1;
        root.dayTotal = 0;
        if (root.mode === "clock")
          root.view = "today";
        root.dayOffset += step;
      }
    }
  }
  // Clicking the island while it's open clears the grab *and* lands as a tap;
  // without this the tap would open it straight back up.
  property real grabClearedAt: 0
  readonly property var moment: Moments.moment
  readonly property bool musicOn: Media.hasPlayer && Media.playing

  readonly property string mode: {
    if (view === "search")
      return "search";
    // A volume change or toggle shouldn't fold away a card you have open.
    if (moment && !(view !== "" && (moment.kind === "level" || moment.kind === "toast")))
      return moment.kind;
    if (view === "player" && Media.hasPlayer)
      return "player";
    if (view === "inbox" && Notifications.count > 0)
      return "inbox";
    if (view === "today" || view === "player")
      return "today";
    if (AiChat.streaming && !AiChat.open)
      return "thinking";
    if (Updates.installing)
      return "installing";
    if (musicOn)
      return "music";
    if (Tones.timing)
      return "timer";
    if (Tones.active)
      return "tone";
    return "clock";
  }

  // The timer splits off into its own bubble whenever something else holds
  // the island.
  readonly property bool bubbleShown: Tones.timing && mode !== "timer" && mode !== "player" && mode !== "today" && mode !== "inbox" && mode !== "search"

  onModeChanged: {
    root.settled = false;
    settleTimer.restart();
    if (mode === "shot")
      shutter.restart();
  }

  // Close the player if the music goes away under it.
  Connections {
    target: Media
    function onHasPlayerChanged() {
      if (!Media.hasPlayer && root.view === "player")
        root.view = "";
    }
  }

  // The inbox folds itself away once the last notification is gone.
  Connections {
    target: Notifications
    function onCountChanged() {
      if (Notifications.count === 0 && root.view === "inbox")
        root.view = "";
    }
  }

  // ------------------------------------------------------------------ inbox
  // Notifications stack by app, newest app first. A stack opens to show every
  // one in it; only one stack is open at a time.
  property string openGroup: ""

  readonly property var inboxGroups: {
    const groups = [];
    for (const n of Notifications.history) {
      const app = n.appName || "Other";
      let g = groups.find(x => x.app === app);
      if (!g) {
        g = {
          app: app,
          items: []
        };
        groups.push(g);
      }
      g.items.push(n);
    }
    return groups;
  }

  readonly property var inboxItems: {
    const out = [];
    for (const g of inboxGroups) {
      if (g.app === openGroup) {
        g.items.forEach((n, i) => out.push({
              n: n,
              app: g.app,
              more: 0,
              collapsible: i === 0 && g.items.length > 1
            }));
      } else {
        out.push({
          n: g.items[0],
          app: g.app,
          more: g.items.length - 1,
          collapsible: false
        });
      }
    }
    return out.slice(0, 4);
  }

  // Lives out here because invoking usually removes the notification, which
  // destroys the row that was clicked while its handler is still running.
  function openNotification(n, action) {
    root.view = "";
    if (action)
      action.invoke();
    if (Notifications.history.includes(n))
      Notifications.dismiss(n);
  }

  function noteActions(n) {
    return Array.from(n.actions).filter(a => a.identifier !== "default");
  }

  function noteHeight(item) {
    return 50 + (noteActions(item.n).length > 0 ? 32 : 0) + (item.more > 0 ? 5 : 0);
  }

  readonly property int inboxHidden: Notifications.count - inboxItems.reduce((sum, i) => sum + 1 + i.more, 0)
  readonly property real inboxHeight: 12 + 24 + inboxItems.reduce((sum, i) => sum + 8 + noteHeight(i), 0) + (inboxHidden > 0 ? 8 + 16 : 0) + 14

  // Progress only needs polling while the player is open.
  Binding {
    target: Media
    property: "trackPosition"
    value: true
    when: root.mode === "player"
  }

  readonly property var size: sizeFor(mode)

  function sizeFor(m) {
    switch (m) {
    case "clock":
      return [clockRow.implicitWidth + 34, compactH];
    case "music":
      return [200, compactH];
    case "timer":
    case "tone":
      return [236, compactH];
    case "thinking":
      return [thinkingRow.implicitWidth + 36, compactH];
    case "installing":
      return [300, compactH];
    case "player":
      return [400, 154];
    case "today":
      return [400, 168];
    case "inbox":
      return [400, inboxHeight];
    case "search":
      return [480, 60 + (results.length > 0 ? results.length * 46 + 8 : 0)];
    case "level":
      return [280, compactH];
    case "toast":
      return [toastRow.implicitWidth + 30, compactH];
    case "palette":
      return [paletteRow.implicitWidth + 36, compactH];
    case "charging":
      return [250, compactH];
    case "shot":
      return [330, 64];
    case "notification":
    case "answer":
      return [390, 68];
    }
    return [200, compactH];
  }

  function screenName() {
    return root.screen ? root.screen.name : "";
  }

  function tap(button) {
    if (button === Qt.RightButton) {
      if (Media.hasPlayer && Media.active.canTogglePlaying)
        Media.active.togglePlaying();
      return;
    }
    switch (mode) {
    case "notification":
      Moments.dismiss();
      root.view = "inbox";
      return;
    case "shot":
      if (root.moment.image)
        Quickshell.execDetached(["xdg-open", root.moment.image]);
      Moments.dismiss();
      return;
    case "answer":
    case "thinking":
      Moments.dismiss();
      if (!AiChat.open)
        AiChat.toggle();
      return;
    case "player":
    case "today":
    case "inbox":
      root.view = "";
      return;
    case "music":
    case "timer":
    case "tone":
    case "clock":
      if (Date.now() - root.grabClearedAt < 400)
        return;
      // Music opens the player; otherwise waiting notifications come first.
      if (mode === "music")
        root.view = "player";
      else if (Notifications.count > 0)
        root.view = "inbox";
      else
        root.view = Media.hasPlayer ? "player" : "today";
      return;
    }
    Moments.dismiss();
  }

  // Clicking anywhere else folds the island back up.
  HyprlandFocusGrab {
    windows: [root]
    active: root.mode === "player" || root.mode === "today" || root.mode === "inbox" || root.mode === "search"
    onCleared: {
      root.grabClearedAt = Date.now();
      root.view = "";
    }
  }

  // The day the Today card is on: today, unless you've scrolled away.
  readonly property date shownDay: {
    const now = Time.now;
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset);
  }

  readonly property string shownDayLabel: {
    const base = Qt.formatDateTime(shownDay, "dddd, d MMMM");
    if (dayOffset === 0)
      return base;
    const n = Math.abs(dayOffset);
    if (n === 1)
      return base + " · " + (dayOffset > 0 ? "tomorrow" : "yesterday");
    return base + " · " + (dayOffset > 0 ? "in " + n + " days" : n + " days ago");
  }

  // Monday-first days of the week the Today card is showing.
  readonly property var week: {
    const now = Time.now;
    const shown = shownDay;
    const monday = new Date(shown.getFullYear(), shown.getMonth(), shown.getDate() - (shown.getDay() + 6) % 7);
    const names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
    const out = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
      out.push({
        name: names[i],
        day: d.getDate(),
        today: d.toDateString() === now.toDateString(),
        picked: root.dayOffset !== 0 && d.toDateString() === shown.toDateString()
      });
    }
    return out;
  }

  // --------------------------------------------------------- layer anatomy
  // One mode's content. Hidden layers shrink away quickly; the incoming one
  // waits a beat for the island to start moving, then grows in with a little
  // overshoot.
  component Layer: Item {
    id: layer

    required property string key
    readonly property bool shown: root.mode === key

    x: (parent.width - root.tailNow - width) / 2
    y: 0
    // Each layer keeps its own size, so one that is leaving doesn't stretch
    // to fit whatever is arriving.
    width: root.sizeFor(key)[0]
    height: root.sizeFor(key)[1]
    opacity: 0
    scale: 0.88
    visible: opacity > 0.01

    states: State {
      name: "on"
      when: layer.shown
      PropertyChanges {
        layer.opacity: 1
        layer.scale: 1
      }
    }

    transitions: [
      Transition {
        to: "on"
        ParallelAnimation {
          SequentialAnimation {
            PauseAnimation {
              duration: 140
            }
            NumberAnimation {
              property: "opacity"
              duration: 360
              easing.type: Easing.OutQuad
            }
          }
          SequentialAnimation {
            PauseAnimation {
              duration: 80
            }
            NumberAnimation {
              property: "scale"
              duration: root.morphMs
              easing.type: Easing.BezierSpline
              easing.bezierCurve: root.popCurve
            }
          }
        }
      },
      Transition {
        from: "on"
        ParallelAnimation {
          NumberAnimation {
            property: "opacity"
            duration: 180
            easing.type: Easing.OutQuad
          }
          NumberAnimation {
            property: "scale"
            duration: 380
            easing.type: Easing.InOutQuad
          }
        }
      }
    ]
  }

  component Art: ClippingRectangle {
    id: art

    property int corner: 6

    radius: corner
    color: root.hot

    // Shown when the player offers no cover art.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop {
          position: 0
          color: root.hot
        }
        GradientStop {
          position: 1
          color: Qt.darker(root.hot, 2.4)
        }
      }
    }

    Image {
      anchors.fill: parent
      source: Media.artUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: art.width * 3
      sourceSize.height: art.height * 3
      smooth: true
      mipmap: true
      visible: status === Image.Ready
    }
  }

  // A thin ring that fills as the focus session goes on.
  component Ring: Shape {
    id: ring

    property real progress: Tones.timerProgress
    property real thickness: 2.5

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: Qt.rgba(1, 1, 1, 0.16)
      strokeWidth: ring.thickness
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.width / 2
        centerY: ring.height / 2
        radiusX: ring.width / 2 - ring.thickness
        radiusY: ring.height / 2 - ring.thickness
        startAngle: 0
        sweepAngle: 360
      }
    }

    ShapePath {
      strokeColor: root.hot
      strokeWidth: ring.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2
        centerY: ring.height / 2
        radiusX: ring.width / 2 - ring.thickness
        radiusY: ring.height / 2 - ring.thickness
        startAngle: -90
        sweepAngle: Math.max(1, 360 * (1 - ring.progress))
      }
    }
  }

  component Ink: Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: root.ink
    elide: Text.ElideRight
  }

  // ------------------------------------------------------------- the island
  // Everything is centred as a group: the island, plus the timer bubble and the
  // keep-awake dot when they're out.
  // Built from the *animated* widths, so the group re-centres every frame as
  // the island grows, instead of a second animation chasing the first.
  readonly property real groupWidth: shape.width + (bubble.width > 0.5 ? bubble.width + 6 : 0) + dot.scale * 13

  // What takes input: the island and its satellites. Sized from where the
  // island is *going*, so the input region changes once per mode rather than
  // on every animation frame.
  readonly property real targetGroupWidth: size[0] + (bubbleShown ? compactH + 6 : 0) + tailTarget + (IdleInhibit.enabled ? 13 : 0)

  // Unread notifications: the island grows a section on its right with the
  // bell and a count. They never pop open on arrival; the bell just hops.
  // Only on the slim island — the big cards have their own layout.
  readonly property bool noteShown: Notifications.count > 0 && !Notifications.doNotDisturb && size[1] === compactH
  readonly property real tailTarget: noteShown ? noteRow.implicitWidth + 24 : 0

  // The same value, animated in step with the island's width, so the main
  // content can stay centred in whatever isn't the tail.
  property real tailNow: tailTarget
  Behavior on tailNow {
    NumberAnimation {
      duration: root.morphMs
      easing.type: Easing.BezierSpline
      easing.bezierCurve: root.shapeCurve
    }
  }

  Item {
    id: hit
    x: (root.width - root.targetGroupWidth) / 2 - 4
    y: 0
    width: root.targetGroupWidth + 8
    height: shape.y + Math.max(root.size[1], root.compactH) + 6
  }

  // Soft coloured light under the island while charging or thinking.
  Rectangle {
    id: glowSource
    x: shape.x
    y: shape.y
    width: shape.width
    height: shape.height
    radius: shape.radius
    visible: false
    // Only rendered while it can be seen; otherwise it would redraw on every
    // frame of every morph for nothing.
    layer.enabled: glow.visible
    color: root.mode === "charging" ? root.good : root.mode === "player" ? root.tint : root.hot
  }

  MultiEffect {
    id: glow
    visible: opacity > 0.01
    anchors.fill: glowSource
    source: glowSource
    blurEnabled: true
    blur: 1.0
    blurMax: 32
    autoPaddingEnabled: true
    // The player's glow waits for the morph to finish; blurring a resizing
    // shape every frame is what made this stutter before.
    opacity: root.mode === "charging" || root.mode === "thinking" ? 0.7 : root.mode === "player" && root.settled && Media.hasCoverTint ? 0.42 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: 500
      }
    }
  }

  Rectangle {
    id: shape

    x: (root.width - root.groupWidth) / 2
    y: Math.round((Theme.barHeight - root.compactH) / 2)
    width: root.size[0] + root.tailTarget
    height: root.size[1]
    radius: Math.min(height / 2, 30)
    color: "#050403"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    clip: true
    scale: tapArea.pressed ? 0.96 : 1
    transform: Translate {
      x: root.nudge
    }

    Behavior on width {
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }
    Behavior on height {
      NumberAnimation {
        duration: root.mode === "search" && root.settled ? 200 : root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.mode === "search" && root.settled ? [0.2, 0.8, 0.2, 1, 1, 1] : root.shapeCurve
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: 380
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
      }
    }

    MouseArea {
      id: tapArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: event => root.tap(event.button)
      onWheel: wheel => root.scrolled(wheel)
    }

    // ------------------------------------------------- notification tail
    Item {
      id: tail

      anchors.right: parent.right
      y: 0
      width: root.tailNow
      height: root.compactH
      opacity: root.noteShown ? 1 : 0
      visible: width > 0.5

      Behavior on opacity {
        NumberAnimation {
          duration: 260
        }
      }

      // A hairline between the island's content and the count.
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: Qt.rgba(1, 1, 1, 0.14)
      }

      Row {
        id: noteRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 1
        spacing: 5

        property real bump: 1
        property int lastCount: Notifications.count
        scale: bump

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.bellBadge
          color: root.hot
        }
        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Notifications.count
          font.bold: true
        }

        // A little hop when another one lands.
        SequentialAnimation {
          id: hop
          NumberAnimation {
            target: noteRow
            property: "bump"
            to: 1.25
            duration: 150
            easing.type: Easing.OutQuad
          }
          NumberAnimation {
            target: noteRow
            property: "bump"
            to: 1
            duration: 520
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.popCurve
          }
        }

        Connections {
          target: Notifications
          function onCountChanged() {
            if (Notifications.count > noteRow.lastCount)
              hop.restart();
            noteRow.lastCount = Notifications.count;
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Moments.dismiss();
          root.view = "inbox";
        }
      }
    }

    // A camera-shutter flash when a screenshot lands.
    Rectangle {
      id: flash
      anchors.fill: parent
      radius: parent.radius
      color: "white"
      opacity: 0
      z: 10

      NumberAnimation on opacity {
        id: shutter
        running: false
        from: 0.85
        to: 0
        duration: 520
        easing.type: Easing.OutCubic
      }
    }

    // ------------------------------------------------------------- clock
    Layer {
      key: "clock"

      Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        Ink {
          text: Time.time
          font.bold: true
        }
        Ink {
          text: Time.date
          color: root.inkDim
        }

        // Do not disturb: a quiet reminder, since the bar has no bell now.
        Ink {
          visible: Notifications.doNotDisturb
          text: Icons.bellOff
          color: root.inkDim
        }

      }
    }

    // ------------------------------------------------------------- music
    Layer {
      key: "music"

      // Barely rounded, so the cover reads as a cover rather than a blob.
      Art {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        corner: 4
      }

      Ink {
        anchors.centerIn: parent
        text: Time.time
        font.bold: true
      }

      Spectrum {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        bars: 4
        maxHeight: 14
        color: root.tint
        active: Media.playing && root.mode === "music"
      }
    }

    // ------------------------------------------------------------- timer
    Layer {
      key: "timer"

      Ring {
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
      }

      Ink {
        anchors.centerIn: parent
        text: Time.time
        font.bold: true
      }

      Ink {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Tones.formatLeft(Tones.timerLeft)
        font.bold: true
        color: root.hot
      }
    }

    // -------------------------------------------------------------- tone
    // A healing tone is sounding (and nothing louder holds the island).
    Layer {
      key: "tone"

      Ink {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.sineWave
        color: root.hot
        font.pixelSize: Theme.iconSize

        SequentialAnimation on opacity {
          running: root.mode === "tone"
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.4
            duration: 1400
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            to: 1
            duration: 1400
            easing.type: Easing.InOutSine
          }
        }
      }

      Ink {
        anchors.centerIn: parent
        text: Time.time
        font.bold: true
      }

      Ink {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Tones.playing + " Hz"
        font.bold: true
        color: root.hot
      }
    }

    // ---------------------------------------------------------- thinking
    Layer {
      key: "thinking"

      Row {
        id: thinkingRow
        anchors.centerIn: parent
        spacing: 8

        Ink {
          text: Icons.ai
          color: root.hot
          font.pixelSize: Theme.iconSize

          SequentialAnimation on scale {
            running: root.mode === "thinking"
            loops: Animation.Infinite
            NumberAnimation {
              to: 0.7
              duration: 600
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 1
              duration: 600
              easing.type: Easing.InOutSine
            }
          }
        }

        Ink {
          text: "Thinking…"

          SequentialAnimation on opacity {
            running: root.mode === "thinking"
            loops: Animation.Infinite
            NumberAnimation {
              to: 0.45
              duration: 700
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 1
              duration: 700
              easing.type: Easing.InOutSine
            }
          }
        }
      }
    }

    // -------------------------------------------------------- installing
    Layer {
      key: "installing"

      Row {
        anchors.centerIn: parent
        spacing: 10

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.download
          color: root.hot
          font.pixelSize: Theme.iconSize
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Updates.count > 0 ? "Installing " + Updates.count + " update" + (Updates.count === 1 ? "" : "s") : "Installing updates"
        }

        // Indeterminate: a segment sliding along the track.
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 80
          height: 5
          radius: 2.5
          color: Qt.rgba(1, 1, 1, 0.14)
          clip: true

          Rectangle {
            width: 28
            height: parent.height
            radius: 2.5
            color: root.hot

            SequentialAnimation on x {
              running: root.mode === "installing"
              loops: Animation.Infinite
              NumberAnimation {
                from: -28
                to: 80
                duration: 1100
                easing.type: Easing.InOutCubic
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- search
    Layer {
      key: "search"

      Ink {
        id: searchGlyph
        x: 20
        y: 12 + (36 - height) / 2
        text: Icons.search
        font.pixelSize: Theme.iconSize + 3
        color: root.tint
      }

      TextInput {
        id: searchField

        anchors.left: searchGlyph.right
        anchors.leftMargin: 13
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 12 + (36 - height) / 2
        color: root.ink
        selectionColor: root.hot
        selectedTextColor: "#140f08"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 4
        clip: true

        onTextChanged: root.query = text

        Keys.onPressed: event => {
          const count = root.results.length;
          const ctrl = event.modifiers & Qt.ControlModifier;
          if (event.key === Qt.Key_Escape) {
            root.view = "";
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.runSelected();
          } else if (count > 0 && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N))) {
            root.selected = (root.selected + 1) % count;
          } else if (count > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P))) {
            root.selected = (root.selected - 1 + count) % count;
          } else {
            return;
          }
          event.accepted = true;
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          visible: searchField.text.length === 0
          text: "Search apps, windows, clipboard, or do a sum"
          color: root.inkDim
          font.pixelSize: Theme.fontSize + 2
        }
      }

      Item {
        id: resultList
        x: 10
        y: 60
        width: parent.width - 20
        height: root.results.length * 46

        // One highlight that glides between rows.
        Rectangle {
          visible: root.results.length > 0
          y: root.selected * 46
          width: parent.width
          height: 46
          radius: 15
          color: Qt.rgba(1, 1, 1, 0.11)

          Behavior on y {
            NumberAnimation {
              duration: 170
              easing.type: Easing.OutCubic
            }
          }
        }

        Repeater {
          model: root.results

          delegate: Item {
            id: resultRow

            required property var modelData
            required property int index

            y: index * 46
            width: resultList.width
            height: 46

            Rectangle {
              id: resultIconBox
              anchors.left: parent.left
              anchors.leftMargin: 9
              anchors.verticalCenter: parent.verticalCenter
              width: 30
              height: 30
              radius: 9
              color: resultRow.modelData.icon ? "transparent" : Qt.rgba(1, 1, 1, 0.1)

              IconImage {
                anchors.fill: parent
                visible: resultRow.modelData.icon.length > 0
                source: resultRow.modelData.icon
                asynchronous: true
              }

              Ink {
                anchors.centerIn: parent
                visible: resultRow.modelData.icon.length === 0
                text: resultRow.modelData.glyph
                font.pixelSize: Theme.iconSize + 1
              }
            }

            Column {
              anchors.left: resultIconBox.right
              anchors.leftMargin: 12
              anchors.right: resultKind.left
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Ink {
                width: parent.width
                text: resultRow.modelData.title
                textFormat: Text.PlainText
                font.bold: true
              }
              Ink {
                width: parent.width
                visible: text.length > 0
                text: resultRow.modelData.sub
                textFormat: Text.PlainText
                color: root.inkDim
                font.pixelSize: Theme.smallSize + 1
              }
            }

            Ink {
              id: resultKind
              anchors.right: parent.right
              anchors.rightMargin: 13
              anchors.verticalCenter: parent.verticalCenter
              text: resultRow.modelData.label
              color: root.inkDim
              font.pixelSize: Theme.smallSize
            }

            // Follows real movement only: new rows report a position the
            // moment they appear under a resting pointer, and that must not
            // steal the selection from the keyboard.
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: mouse => {
                const at = mapToItem(null, mouse.x, mouse.y);
                if (root.pointerMoved(at.x, at.y))
                  root.selected = resultRow.index;
              }
              onClicked: {
                root.selected = resultRow.index;
                root.runSelected();
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- inbox
    // Stacked by app. Click a stack to open it, click a single notification to
    // open its app; × dismisses (a whole stack, if it's closed); the app's own
    // buttons sit underneath.
    Layer {
      key: "inbox"

      Column {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 12
        spacing: 8

        Item {
          width: parent.width
          height: 24

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Ink {
              text: "Notifications"
              font.bold: true
            }
            Ink {
              text: Notifications.count
              color: root.inkDim
            }
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearText.implicitWidth + 18
            height: 22
            radius: 11
            color: clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

            Ink {
              id: clearText
              anchors.centerIn: parent
              text: "Clear all"
              font.pixelSize: Theme.smallSize + 1
            }

            MouseArea {
              id: clearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Notifications.clearAll()
            }
          }
        }

        Repeater {
          model: root.inboxItems

          delegate: Item {
            id: note

            required property var modelData
            readonly property var n: modelData.n
            readonly property int more: modelData.more
            readonly property var actions: root.noteActions(n)
            readonly property string icon: Notifications.iconFor(n)

            width: parent.width
            height: root.noteHeight(modelData)

            // The edge of the next card, peeking out under a closed stack.
            Rectangle {
              visible: note.more > 0
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 18
              height: 14
              radius: 7
              color: Qt.rgba(1, 1, 1, 0.05)
            }

            Rectangle {
              id: noteCard
              width: parent.width
              height: parent.height - (note.more > 0 ? 5 : 0)
              radius: 14
              color: noteArea.containsMouse ? Qt.rgba(0.17, 0.17, 0.17, 1) : Qt.rgba(0.09, 0.09, 0.09, 1)

              Behavior on color {
                ColorAnimation {
                  duration: 140
                }
              }

              MouseArea {
                id: noteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (note.more > 0) {
                    root.openGroup = note.modelData.app;
                    return;
                  }
                  root.openNotification(note.n, Array.from(note.n.actions).find(a => a.identifier === "default"));
                }
              }

              Rectangle {
                id: noteIconBox
                x: 9
                y: 9
                width: 32
                height: 32
                radius: 10
                color: inboxIcon.status === Image.Ready ? "transparent" : root.hot

                IconImage {
                  id: inboxIcon
                  anchors.fill: parent
                  source: note.icon.length === 0 ? "" : note.icon.startsWith("/") ? "file://" + note.icon : note.icon
                  visible: status === Image.Ready
                }

                Ink {
                  anchors.centerIn: parent
                  visible: inboxIcon.status !== Image.Ready
                  text: Icons.bell
                  color: "#140f08"
                }
              }

              Column {
                anchors.left: noteIconBox.right
                anchors.leftMargin: 10
                anchors.right: dismissBox.left
                anchors.rightMargin: 6
                y: 8
                spacing: 2

                Item {
                  width: parent.width
                  height: summaryText.implicitHeight

                  Ink {
                    id: summaryText
                    anchors.left: parent.left
                    anchors.right: noteMeta.left
                    anchors.rightMargin: 6
                    text: note.n.summary || note.n.appName
                    textFormat: Text.PlainText
                    font.bold: true
                  }

                  Row {
                    id: noteMeta
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // "+2" on a closed stack; a chevron to fold an open one.
                    Rectangle {
                      visible: note.more > 0 || note.modelData.collapsible
                      anchors.verticalCenter: parent.verticalCenter
                      width: stackLabel.implicitWidth + 12
                      height: 16
                      radius: 8
                      color: Qt.rgba(1, 1, 1, 0.14)

                      Ink {
                        id: stackLabel
                        anchors.centerIn: parent
                        text: note.more > 0 ? "+" + note.more : Icons.chevronUp
                        font.pixelSize: Theme.smallSize
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openGroup = note.more > 0 ? note.modelData.app : ""
                      }
                    }

                    Ink {
                      anchors.verticalCenter: parent.verticalCenter
                      text: Notifications.ageText(note.n)
                      color: root.inkDim
                      font.pixelSize: Theme.smallSize
                    }
                  }
                }

                Ink {
                  width: parent.width
                  text: String(note.n.body).replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                  textFormat: Text.PlainText
                  color: root.inkDim
                  font.pixelSize: Theme.smallSize + 1
                }
              }

              Rectangle {
                id: dismissBox
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 14
                width: 22
                height: 22
                radius: 11
                color: dismissArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                Ink {
                  anchors.centerIn: parent
                  text: Icons.close
                  font.pixelSize: Theme.smallSize + 1
                  color: dismissArea.containsMouse ? root.ink : root.inkDim
                }

                MouseArea {
                  id: dismissArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (note.more > 0) {
                      const group = root.inboxGroups.find(g => g.app === note.modelData.app);
                      for (const item of group.items.slice())
                        Notifications.dismiss(item);
                    } else {
                      Notifications.dismiss(note.n);
                    }
                  }
                }
              }

              // The app's own buttons ("Reply", "Mark as read"…).
              Row {
                visible: note.actions.length > 0
                x: 51
                y: 50
                spacing: 6

                Repeater {
                  model: note.actions

                  delegate: Rectangle {
                    id: actionChip

                    required property var modelData

                    width: Math.min(130, actionText.implicitWidth + 20)
                    height: 24
                    radius: 12
                    color: actionArea.containsMouse ? root.hot : Qt.rgba(1, 1, 1, 0.12)

                    Behavior on color {
                      ColorAnimation {
                        duration: 140
                      }
                    }

                    Ink {
                      id: actionText
                      anchors.centerIn: parent
                      width: Math.min(implicitWidth, 110)
                      text: actionChip.modelData.text
                      textFormat: Text.PlainText
                      font.pixelSize: Theme.smallSize + 1
                      color: actionArea.containsMouse ? "#140f08" : root.ink
                    }

                    MouseArea {
                      id: actionArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.openNotification(note.n, actionChip.modelData);
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Ink {
          visible: root.inboxHidden > 0
          anchors.horizontalCenter: parent.horizontalCenter
          text: "+" + root.inboxHidden + " more · open all"
          color: moreArea.containsMouse ? root.hot : root.inkDim
          font.pixelSize: Theme.smallSize + 1

          MouseArea {
            id: moreArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.view = "";
              Moments.popupRequested("notifications", root.screenName());
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- today
    // What a click on the clock opens when nothing is playing: the time large,
    // this week, and the focus timer one click away.
    Layer {
      key: "today"

      Item {
        anchors.fill: parent
        anchors.margins: 16

        Column {
          id: todayTime
          anchors.left: parent.left
          anchors.top: parent.top
          spacing: 2

          Ink {
            text: Time.time
            font.bold: true
            font.pixelSize: 30
          }
          Ink {
            text: root.shownDayLabel
            color: root.inkDim
          }
        }

        // Battery and keep awake, at a glance.
        Column {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 4
          spacing: 6

          Ink {
            anchors.right: parent.right
            text: (Moments.charging ? Icons.batteryCharging + "  " : "") + Moments.batteryPercent + "%"
            color: Moments.charging ? root.good : root.ink
          }
          Ink {
            anchors.right: parent.right
            text: IdleInhibit.enabled ? Icons.coffee + "  awake" : Media.hasPlayer ? "" : "Nothing playing"
            color: IdleInhibit.enabled ? root.hot : root.inkDim
            font.pixelSize: Theme.smallSize + 1
          }
        }

        Row {
          id: weekRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: todayTime.bottom
          anchors.topMargin: 12

          Repeater {
            model: root.week

            delegate: Item {
              id: dayCell

              required property var modelData

              width: weekRow.width / 7
              height: 36

              Ink {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                text: dayCell.modelData.name
                font.pixelSize: Theme.smallSize
                color: dayCell.modelData.today ? root.hot : root.inkDim
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 22
                height: 22
                radius: 11
                color: dayCell.modelData.today ? root.hot : "transparent"
                border.width: dayCell.modelData.picked && !dayCell.modelData.today ? 1.5 : 0
                border.color: root.hot

                Ink {
                  anchors.centerIn: parent
                  text: dayCell.modelData.day
                  font.bold: dayCell.modelData.today
                  color: dayCell.modelData.today ? "#140f08" : root.ink
                }
              }
            }
          }
        }

        // The focus timer: presets, or the time left and a stop.
        Row {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          spacing: 8

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.timer
            color: Tones.timing ? root.hot : root.inkDim
            font.pixelSize: Theme.iconSize
          }

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: Tones.timing ? Tones.formatLeft(Tones.timerLeft) + " left" : "Focus"
            font.bold: Tones.timing
            color: Tones.timing ? root.hot : root.ink
          }

          Item {
            width: 4
            height: 1
          }

          Repeater {
            model: Tones.timing ? ["stop"] : Tones.timerPresets

            delegate: Rectangle {
              id: focusChip

              required property var modelData
              readonly property bool isStop: modelData === "stop"

              anchors.verticalCenter: parent.verticalCenter
              width: focusText.implicitWidth + 18
              height: 24
              radius: 12
              color: focusArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
              scale: focusArea.pressed ? 0.9 : 1

              Behavior on scale {
                SpringAnimation {
                  spring: 6
                  damping: 0.3
                  epsilon: 0.002
                }
              }

              Ink {
                id: focusText
                anchors.centerIn: parent
                text: focusChip.isStop ? "Stop" : focusChip.modelData + " min"
                font.pixelSize: Theme.smallSize + 1
              }

              MouseArea {
                id: focusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (focusChip.isStop) {
                    Tones.stopTimer();
                  } else {
                    Tones.startTimer(focusChip.modelData);
                    root.view = "";
                  }
                }
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------ player
    Layer {
      key: "player"

      // A wash of the cover's colour from the left.
      Rectangle {
        anchors.fill: parent
        radius: shape.radius
        visible: Media.hasCoverTint
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop {
            position: 0
            color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.3)
          }
          GradientStop {
            position: 0.75
            color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0)
          }
        }
      }

      // Appears while you scroll to change the volume here.
      Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 11
        anchors.rightMargin: 18
        spacing: 4
        opacity: root.volumeShown ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: 180
          }
        }

        Ink {
          text: Icons.volHigh
          font.pixelSize: Theme.smallSize + 1
          color: root.tint
        }
        Ink {
          text: Moments.sink && Moments.sink.audio ? Math.round(Moments.sink.audio.volume * 100) : ""
          font.pixelSize: Theme.smallSize + 1
          font.bold: true
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
          width: parent.width
          spacing: 14

          Art {
            width: 56
            height: 56
            corner: 14
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56 - 14 - 40 - 14
            spacing: 3

            Ink {
              width: parent.width
              text: Media.title || "Nothing playing"
              font.bold: true
              font.pixelSize: Theme.fontSize + 2
            }
            Ink {
              width: parent.width
              text: Media.artist
              color: root.inkDim
            }
          }

          Spectrum {
            anchors.verticalCenter: parent.verticalCenter
            bars: 5
            barWidth: 4
            barSpacing: 3
            minHeight: 4
            maxHeight: 24
            color: root.tint
            active: Media.playing && root.mode === "player"
          }
        }

        Row {
          width: parent.width
          spacing: 10

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: Media.formatTime(Media.position)
            color: root.inkDim
            font.pixelSize: Theme.smallSize
          }

          Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
              width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
              height: parent.height
              radius: 2
              color: root.tint

              Behavior on width {
                NumberAnimation {
                  duration: 900
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              enabled: Media.seekable
              cursorShape: Qt.PointingHandCursor
              onClicked: mouse => Media.active.position = Media.length * Math.max(0, Math.min(1, mouse.x / track.width))
            }
          }

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: Media.formatTime(Media.length)
            color: root.inkDim
            font.pixelSize: Theme.smallSize
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 22

          Repeater {
            model: [
              {
                glyph: Icons.prev,
                act: "prev"
              },
              {
                glyph: Media.playing ? Icons.pause : Icons.play,
                act: "toggle"
              },
              {
                glyph: Icons.next,
                act: "next"
              }
            ]

            delegate: Rectangle {
              id: ctl

              required property var modelData
              readonly property bool main: modelData.act === "toggle"

              width: main ? 40 : 32
              height: width
              radius: width / 2
              color: ctlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : main ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
              scale: ctlArea.pressed ? 0.84 : 1

              Behavior on scale {
                SpringAnimation {
                  spring: 6
                  damping: 0.3
                  epsilon: 0.002
                }
              }

              Ink {
                anchors.centerIn: parent
                text: ctl.modelData.glyph
                font.pixelSize: ctl.main ? Theme.iconSize + 4 : Theme.iconSize + 1
              }

              MouseArea {
                id: ctlArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  const p = Media.active;
                  if (!p)
                    return;
                  if (ctl.modelData.act === "prev" && p.canGoPrevious)
                    p.previous();
                  else if (ctl.modelData.act === "next" && p.canGoNext)
                    p.next();
                  else if (ctl.modelData.act === "toggle" && p.canTogglePlaying)
                    p.togglePlaying();
                }
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- level
    Layer {
      id: levelLayer
      key: "level"

      readonly property string which: root.moment && root.moment.kind === "level" ? root.moment.which : "volume"
      readonly property real value: root.moment && root.moment.kind === "level" ? root.moment.value : 0

      Row {
        anchors.centerIn: parent
        spacing: 12

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: Theme.iconSize
          color: levelLayer.which === "mute" ? root.inkDim : root.hot
          text: {
            switch (levelLayer.which) {
            case "mute":
              return Icons.volMute;
            case "brightness":
              return Icons.brightness;
            case "warmth":
              return Icons.warmth;
            }
            return Icons.volHigh;
          }
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 160
          height: 6
          radius: 3
          color: Qt.rgba(1, 1, 1, 0.14)

          Rectangle {
            width: Math.max(height, parent.width * levelLayer.value)
            height: parent.height
            radius: 3
            color: levelLayer.which === "mute" ? root.inkDim : root.hot

            Behavior on width {
              NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          width: 28
          horizontalAlignment: Text.AlignRight
          text: levelLayer.which === "mute" ? "off" : Math.round(levelLayer.value * 100)
          font.bold: true
        }
      }
    }

    // ------------------------------------------------------------- toast
    Layer {
      id: toastLayer
      key: "toast"

      readonly property var m: root.moment && root.moment.kind === "toast" ? root.moment : ({
          glyph: "",
          label: "",
          state: "",
          on: true
        })

      Row {
        id: toastRow
        anchors.centerIn: parent
        spacing: 10

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: toastLayer.m.glyph
          font.pixelSize: Theme.iconSize
          color: toastLayer.m.on ? root.hot : root.inkDim
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: toastLayer.m.label
          font.bold: true
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: chipText.implicitWidth + 14
          height: 18
          radius: 9
          color: toastLayer.m.on ? root.hot : Qt.rgba(1, 1, 1, 0.14)

          Ink {
            id: chipText
            anchors.centerIn: parent
            text: toastLayer.m.state
            font.pixelSize: Theme.smallSize
            font.bold: true
            color: toastLayer.m.on ? "#140f08" : root.ink
          }
        }
      }
    }

    // ----------------------------------------------------------- palette
    Layer {
      id: paletteLayer
      key: "palette"

      readonly property var colors: root.moment && root.moment.kind === "palette" ? root.moment.colors : []

      Row {
        id: paletteRow
        anchors.centerIn: parent
        spacing: 7

        Repeater {
          model: paletteLayer.colors

          delegate: Rectangle {
            id: swatch

            required property var modelData
            required property int index

            property bool popped: false

            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: modelData
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            scale: popped ? 1 : 0

            Behavior on scale {
              NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 2
              }
            }

            // One after another, once the island has opened up.
            Timer {
              running: paletteLayer.shown
              interval: 180 + swatch.index * 70
              onTriggered: swatch.popped = true
            }
            Connections {
              target: paletteLayer
              function onShownChanged() {
                if (!paletteLayer.shown)
                  swatch.popped = false;
              }
            }
          }
        }

        Item {
          width: 4
          height: 1
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: "Theme updated"
          font.bold: true
        }
      }
    }

    // ---------------------------------------------------------- charging
    Layer {
      key: "charging"

      Row {
        anchors.centerIn: parent
        spacing: 10

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.batteryCharging
          color: root.good
          font.pixelSize: Theme.iconSize + 2
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: "Charging"
          font.bold: true
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.bolt
          color: root.good

          SequentialAnimation on opacity {
            running: root.mode === "charging"
            loops: Animation.Infinite
            NumberAnimation {
              to: 0.35
              duration: 600
            }
            NumberAnimation {
              to: 1
              duration: 600
            }
          }
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Moments.batteryPercent + "%"
          font.bold: true
          color: root.good
        }
      }
    }

    // ------------------------------------------------------------ screenshot
    Layer {
      id: shotLayer
      key: "shot"

      readonly property string image: root.moment && root.moment.kind === "shot" ? String(root.moment.image) : ""

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        ClippingRectangle {
          id: thumb
          anchors.verticalCenter: parent.verticalCenter
          width: 76
          height: 46
          radius: 9
          color: Qt.rgba(1, 1, 1, 0.1)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.2)
          rotation: shotLayer.shown ? 0 : -6
          scale: shotLayer.shown ? 1 : 0.6

          Behavior on rotation {
            NumberAnimation {
              duration: 700
              easing.type: Easing.OutBack
            }
          }
          Behavior on scale {
            NumberAnimation {
              duration: 700
              easing.type: Easing.OutBack
              easing.overshoot: 1.8
            }
          }

          Image {
            anchors.fill: parent
            source: shotLayer.image.length === 0 ? "" : shotLayer.image.startsWith("/") ? "file://" + shotLayer.image : shotLayer.image
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 160
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Ink {
            text: "Screenshot saved"
            font.bold: true
          }
          Ink {
            text: "Copied · click to open"
            color: root.inkDim
            font.pixelSize: Theme.smallSize + 1
          }
        }
      }
    }

    // ------------------------------------------------- notification / answer
    Layer {
      id: noteLayer
      key: "notification"

      readonly property var m: root.moment && root.moment.kind === "notification" ? root.moment : null

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 40
          height: 40
          radius: 12
          color: noteIcon.status === Image.Ready ? "transparent" : root.hot

          IconImage {
            id: noteIcon
            anchors.fill: parent
            source: noteLayer.m && noteLayer.m.icon ? (noteLayer.m.icon.startsWith("/") ? "file://" + noteLayer.m.icon : noteLayer.m.icon) : ""
            visible: status === Image.Ready
          }

          Ink {
            anchors.centerIn: parent
            visible: noteIcon.status !== Image.Ready
            text: Icons.bell
            font.pixelSize: Theme.iconSize + 4
            color: "#140f08"
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: 300
          spacing: 3

          Ink {
            width: parent.width
            text: noteLayer.m ? (noteLayer.m.summary || noteLayer.m.appName) : ""
            font.bold: true
          }
          Ink {
            width: parent.width
            text: noteLayer.m ? String(noteLayer.m.body).replace(/<[^>]*>/g, "").replace(/\s+/g, " ") : ""
            color: root.inkDim
            textFormat: Text.PlainText
          }
        }
      }
    }

    Layer {
      id: answerLayer
      key: "answer"

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 40
          height: 40
          radius: 12
          color: root.hot

          Ink {
            anchors.centerIn: parent
            text: Icons.ai
            font.pixelSize: Theme.iconSize + 4
            color: "#140f08"
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: 300
          spacing: 3

          Ink {
            text: "AI assistant · answer ready"
            font.bold: true
          }
          Ink {
            width: parent.width
            text: root.moment && root.moment.kind === "answer" ? root.moment.text : ""
            color: root.inkDim
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ satellites
  // The focus timer, split off into its own bubble.
  Rectangle {
    id: bubble

    x: shape.x + shape.width + (root.bubbleShown ? 6 : 0)
    y: shape.y
    width: root.bubbleShown ? root.compactH : 0
    height: root.compactH
    radius: height / 2
    color: "#050403"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    opacity: root.bubbleShown ? 1 : 0
    scale: root.bubbleShown ? (bubbleArea.pressed ? 0.88 : 1) : 0.3
    visible: opacity > 0.01

    Behavior on width {
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.popCurve
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: 220
      }
    }

    Ring {
      anchors.centerIn: parent
      width: 18
      height: 18
    }

    MouseArea {
      id: bubbleArea
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Moments.popupRequested("tones", root.screenName())
    }
  }

  // Keep awake: a small breathing dot beside the island, like a privacy light.
  Rectangle {
    id: dot

    x: (root.bubbleShown ? bubble.x + bubble.width : shape.x + shape.width) + 6
    y: shape.y + (root.compactH - height) / 2
    width: 7
    height: 7
    radius: 3.5
    color: root.hot
    scale: IdleInhibit.enabled ? 1 : 0
    visible: scale > 0.01

    Behavior on scale {
      NumberAnimation {
        duration: 450
        easing.type: Easing.OutBack
        easing.overshoot: 2
      }
    }

    SequentialAnimation on opacity {
      running: IdleInhibit.enabled
      loops: Animation.Infinite
      NumberAnimation {
        to: 0.45
        duration: 1200
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1
        duration: 1200
        easing.type: Easing.InOutSine
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -5
      cursorShape: Qt.PointingHandCursor
      onClicked: IdleInhibit.enabled = false
    }
  }
}
