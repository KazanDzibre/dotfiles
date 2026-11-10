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
  WlrLayershell.keyboardFocus: mode === "search" || mode === "ask" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  focusable: mode === "search" || mode === "ask"

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

  // A file being dragged over the island.
  property bool dragOver: false
  property bool shelfDragging: false

  // How long the current Claude turn has been going.
  property int claudeElapsed: 0
  Timer {
    running: ClaudeCode.current !== null
    repeat: true
    triggeredOnStart: true
    interval: 1000
    onTriggered: root.claudeElapsed = ClaudeCode.current ? Math.round((Date.now() - ClaudeCode.current.since) / 1000) : 0
  }

  // -------------------------------------------------------------------- ask
  // "?" in the search asks the AI; the answer streams in right here.
  property string question: ""
  readonly property string answer: {
    if (AiChat.error)
      return AiChat.error;
    if (AiChat.partial)
      return AiChat.partial;
    if (AiChat.streaming)
      return "";
    const last = AiChat.messages[AiChat.messages.length - 1];
    return last && last.role === "assistant" ? last.content : "";
  }

  // Typing and streaming resize the island constantly; those need to be quick,
  // not a full spring every time.
  readonly property bool quickResize: (mode === "search" || mode === "ask") && settled

  // ----------------------------------------------------------------- search
  property string query: ""
  onQueryChanged: Spotlight.ask(root.view === "search" ? query : "")
  property int selected: 0
  readonly property var results: view === "search" ? Spotlight.search(query) : []
  onResultsChanged: selected = 0

  function openSearch() {
    Moments.dismiss();
    root.query = "";
    root.lastPointer = Qt.point(-1, -1);
    searchField.text = "";
    root.view = "search";
    focusRetry.target = searchField;
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
    if (item.kind === "ask") {
      if (!item.question || !AiChat.configured)
        return;
      root.question = item.question;
      root.view = "ask";
      focusRetry.target = askKeys;
      focusRetry.attempts = 0;
      focusRetry.restart();
      AiChat.send(item.question);
      return;
    }
    root.view = "";
    Spotlight.run(item);
  }

  // The surface only gets the keyboard once mapped with focus; keep asking.
  Timer {
    id: focusRetry
    property int attempts: 0
    property Item target: null
    interval: 40
    repeat: true
    onTriggered: {
      if ((root.view !== "search" && root.view !== "ask") || !target || target.activeFocus || attempts > 25) {
        stop();
        return;
      }
      attempts++;
      target.forceActiveFocus();
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

  property string previousView: ""

  onViewChanged: {
    root.cancelPeek();
    if (view !== "" && previousView === "")
      Sounds.play("open");
    else if (view === "" && previousView !== "")
      Sounds.play("close");
    previousView = view;
    if (view !== "today") {
      dayOffset = 0;
      monthOffset = 0;
    } else if (Dashboard.stocks.length === 0) {
      Dashboard.refreshStocks();
    }
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
    // Longer than the volume moment lasts, so a peek never flips to it at the end.
    interval: 1600
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

  // Up and down is volume on the slim island and the player, whatever it's
  // showing; on the Today card it walks through the days. Sideways skips on
  // anything showing music. Trackpads send many tiny events and wheels a few
  // big ones, so skips and days add up to a threshold.
  function scrolled(wheel) {
    const dx = wheel.angleDelta.x;
    const dy = wheel.angleDelta.y;
    gestureIdle.restart();
    // Scrolling means you came to do something, not to look: no peek starts now.
    peekDelay.stop();

    if (Math.abs(dx) > Math.abs(dy)) {
      const onMusic = root.mode === "player" || root.mode === "music" || (root.mode === "level" && root.musicOn);
      if (!onMusic || !Media.active)
        return;
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
      return;
    }

    if (root.mode === "today") {
      root.dayTotal += dy;
      if (Math.abs(root.dayTotal) >= 120) {
        root.dayOffset += root.dayTotal > 0 ? -1 : 1;
        root.dayTotal = 0;
      }
      return;
    }

    if ((root.slim || root.mode === "player") && Moments.sink && Moments.sink.audio) {
      const audio = Moments.sink.audio;
      audio.volume = Math.max(0, Math.min(1, audio.volume + dy / 120 * 0.03));
      root.volumeShown = true;
      volumeHide.restart();
    }
  }
  // Clicking the island while it's open clears the grab *and* lands as a tap;
  // without this the tap would open it straight back up.
  property real grabClearedAt: 0
  readonly property var moment: Moments.moment

  // What kind of copy the clipboard layer last showed (see Moments.qml).
  property string clipType: ""
  onMomentChanged: {
    if (moment && moment.kind === "clip")
      clipType = moment.type;
  }
  readonly property bool musicOn: Media.hasPlayer && Media.playing

  readonly property string mode: {
    if (dragOver)
      return "drop";
    if (view === "search")
      return "search";
    if (view === "ask")
      return "ask";
    if (view === "alert" && alertShown)
      return "alertCard";
    // Scrolling the volume while peeking stays in the peek: dropping to the slim
    // volume bar would shrink the island out from under the pointer.
    const peekKeepsVolume = moment && moment.kind === "level" && peekWanted && volumeShown && view === "";
    // A volume change or toggle shouldn't fold away a card you have open.
    if (moment && !peekKeepsVolume && !(view !== "" && (moment.kind === "level" || moment.kind === "toast" || moment.kind === "answer" || moment.kind === "headphones" || moment.kind === "downloaded")))
      return moment.kind;
    if (view === "player" && Media.hasPlayer)
      return "player";
    if (view === "inbox" && Notifications.count > 0)
      return "inbox";
    if (view === "shelf" && Shelf.count > 0)
      return "shelf";
    if (view === "today" || view === "player")
      return "today";
    if (Recorder.recording)
      return "recording";
    if (ClaudeCode.waiting)
      return "claudeWaiting";
    if (AiChat.streaming && !AiChat.open)
      return "thinking";
    if (Updates.installing)
      return "installing";
    if (ClaudeCode.working && !musicOn)
      return "claude";
    if (musicOn)
      return "music";
    if (Downloads.downloading && !musicOn)
      return "download";
    if (Tones.timing)
      return "timer";
    if (Tones.active)
      return "tone";
    return "clock";
  }

  // The timer splits off into its own bubble whenever something else holds
  // the island.
  readonly property bool bubbleShown: Tones.timing && mode !== "timer" && mode !== "player" && mode !== "today" && mode !== "inbox" && mode !== "search" && mode !== "alertCard" && mode !== "ask" && mode !== "shelf"

  // Claude busy while something else holds the island: a little spinning bubble.
  readonly property bool claudeBubbleShown: ClaudeCode.working !== null && mode !== "claude" && mode !== "claudeWaiting" && slim

  // A download while something else holds the island.
  readonly property bool downloadBubbleShown: Downloads.downloading && mode !== "download" && slim

  // Where the last round bubble ends, for the dots that sit after them.
  readonly property real bubblesRight: downloadBubbleShown ? downloadSat.x + downloadSat.width : claudeBubbleShown ? claudeSat.x + claudeSat.width : bubbleShown ? bubble.x + bubble.width : shape.x + shape.width

  // ------------------------------------------------------------- hover peek
  // Rest the pointer on the slim island and it grows a little to say more. The
  // mode underneath doesn't change, so clicks and gestures still act on it, and
  // a scroll that begins before the peek does keeps it from starting at all.
  property bool peekWanted: false
  readonly property bool peeking: peekWanted && view === "" && canPeek(mode)
  readonly property string activeKey: peeking ? "peek" : mode

  function canPeek(m) {
    return ["clock", "music", "timer", "tone", "claude", "download"].includes(m);
  }

  function cancelPeek() {
    peekDelay.stop();
    root.peekWanted = false;
  }

  Timer {
    id: peekDelay
    interval: 450
    onTriggered: {
      if (root.view === "" && root.canPeek(root.mode))
        root.peekWanted = true;
    }
  }

  readonly property string peekTitle: {
    switch (mode) {
    case "clock":
      return Qt.formatDateTime(Time.now, "dddd, d MMMM");
    case "music":
      return Media.title;
    case "timer":
      return "Focus session";
    case "tone":
      return Tones.nameFor(Tones.playing);
    case "claude":
      return ClaudeCode.working ? ClaudeCode.working.project || "Claude" : "Claude";
    case "download":
      return Downloads.label;
    }
    return "";
  }

  readonly property string peekSub: {
    switch (mode) {
    case "clock":
      return Weather.ready ? Weather.tempC + "° · " + Weather.description : Notifications.count > 0 ? Notifications.count + " waiting" : "Nothing waiting";
    case "music":
      return Media.artist;
    case "timer":
      return "Ends at " + Qt.formatDateTime(new Date(Time.now.getTime() + Tones.timerLeft * 1000), "HH:mm");
    case "tone":
      return Tones.playing + " Hz";
    case "claude":
      return ClaudeCode.working ? ClaudeCode.working.detail : "";
    case "download":
      return Downloads.status;
    }
    return "";
  }

  readonly property string peekRight: {
    switch (mode) {
    case "clock":
      return Time.time;
    case "timer":
      return Tones.formatLeft(Tones.timerLeft);
    case "claude":
      return ClaudeCode.formatElapsed(root.claudeElapsed);
    case "download":
      return Downloads.percent;
    }
    return "";
  }

  onModeChanged: {
    root.settled = false;
    settleTimer.restart();
    if (mode === "shot" && !moment.title)
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

  // The alert that was clicked open.
  property var alertShown: null
  readonly property var alertData: moment && moment.kind === "alert" ? moment : alertShown
  readonly property color alertColor: alertData && !alertData.crit ? "#f0c674" : "#f0808f"

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

  readonly property var size: sizeFor(activeKey)

  // Whether the current mode is one of the slim ones, even while it's peeking.
  readonly property bool slim: sizeFor(mode)[1] === compactH

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
      return [400, 154 + (Lyrics.available ? 76 : 0)];
    case "claude":
      return [340, compactH];
    case "claudeWaiting":
      return [400, compactH];
    case "recording":
      return [230, compactH];
    case "download":
      return [290, compactH];
    case "peek":
      return [mode === "claude" ? 430 : 350, 56];
    case "headphones":
      return [340, 76];
    case "downloaded":
      return [420, 64];
    case "drop":
      return [320, 64];
    case "shelf":
      return [420, 12 + 24 + Math.min(Shelf.count, 5) * 52 + 14];
    case "ask":
      return [480, Math.min(440, 14 + 26 + 10 + Math.max(22, askBody.implicitHeight) + 18)];
    case "today":
      return [420, 362 + (Dashboard.stocks.length > 0 ? 38 : 0)];
    case "inbox":
      return [400, inboxHeight];
    case "alert":
      return [320, compactH];
    case "alertCard":
      return [390, 116];
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
    case "clip":
      // By the type the layer last showed, so one that is leaving keeps its
      // own size instead of stretching to fit whatever replaces it.
      switch (clipType) {
      case "color":
        return [490, 86];
      case "link":
        return [450, 86];
      case "file":
        return [410, 86];
      case "unit":
        return [390, 78];
      case "secret":
        return [370, 46];
      }
      return [430, 68];
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
    case "clip":
      Moments.dismiss();
      return;
        Media.active.togglePlaying();
      return;
    }
    switch (mode) {
    case "notification":
      Moments.dismiss();
      root.view = "inbox";
      return;
    case "alert":
      root.alertShown = root.moment;
      Moments.dismiss();
      root.view = "alert";
      return;
    case "alertCard":
      root.view = "";
      return;
    case "headphones":
      Moments.dismiss();
      Moments.popupRequested("bluetooth", root.screenName());
      return;
    case "downloaded":
      Shelf.open(root.moment.path);
      Moments.dismiss();
      return;
    case "shot":
      if (root.moment.open || root.moment.image)
        Quickshell.execDetached(["xdg-open", root.moment.open ?? root.moment.image]);
      Moments.dismiss();
      return;
    case "claude":
    case "claudeWaiting":
      if (ClaudeCode.current)
        ClaudeCode.focus(ClaudeCode.current.window);
      return;
    case "recording":
      Recorder.stop();
      return;
    case "ask":
    case "drop":
      return;
    case "shelf":
      root.view = "";
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
    case "download":
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
    if (root.moment && root.moment.window)
      ClaudeCode.focus(root.moment.window);
    Moments.dismiss();
  }

  // Clicking anywhere else folds the island back up.
  HyprlandFocusGrab {
    windows: [root]
    active: root.mode === "player" || root.mode === "today" || root.mode === "inbox" || root.mode === "search" || root.mode === "alertCard" || root.mode === "ask" || root.mode === "shelf"
    onCleared: {
      // Dragging a file out of the shelf hands the pointer to the drag.
      if (root.shelfDragging)
        return;
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

  // The month grid: six Monday-first weeks. Arrows flip it; scrolling or
  // clicking a day moves the picked day, and the month follows.
  property int monthOffset: 0

  onDayOffsetChanged: {
    const now = Time.now;
    monthOffset = (shownDay.getFullYear() - now.getFullYear()) * 12 + shownDay.getMonth() - now.getMonth();
  }

  readonly property date shownMonth: {
    const now = Time.now;
    return new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
  }

  readonly property var monthDays: {
    const now = Time.now;
    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const first = shownMonth;
    const out = [];
    for (let i = 0; i < 42; i++) {
      const d = new Date(first.getFullYear(), first.getMonth(), 1 - (first.getDay() + 6) % 7 + i);
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === first.getMonth(),
        today: d.toDateString() === now.toDateString(),
        picked: root.dayOffset !== 0 && d.toDateString() === shownDay.toDateString(),
        offset: Math.round((d.getTime() - midnight) / 86400000)
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
    readonly property bool shown: root.activeKey === key

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
    property color tone: root.hot

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
      strokeColor: ring.tone
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

  // A download: fills as it goes, or circles until the size is known.
  component DownloadRing: Ring {
    id: dlRing

    property real spin: 0
    readonly property bool unknown: Downloads.progress < 0

    progress: unknown ? 0.72 : 1 - Downloads.progress
    rotation: unknown ? spin : 0

    NumberAnimation on spin {
      running: Downloads.downloading && dlRing.unknown
      loops: Animation.Infinite
      from: 0
      to: 360
      duration: 1300
    }
  }

  // A small rounded button inside a card.
  component Chip: Rectangle {
    id: chip

    property string label
    property bool strong: false
    signal pressed

    anchors.verticalCenter: parent.verticalCenter
    width: chipLabel.implicitWidth + 22
    height: 26
    radius: 13
    color: strong ? (chipArea.containsMouse ? Qt.lighter(root.hot, 1.1) : root.hot) : chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.11)

    Behavior on color {
      ColorAnimation {
        duration: 140
      }
    }

    Ink {
      id: chipLabel
      anchors.centerIn: parent
      text: chip.label
      font.pixelSize: Theme.smallSize + 1
      font.bold: true
      color: chip.strong ? "#140f08" : root.ink
    }

    MouseArea {
      id: chipArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.pressed()
    }
  }

  // A small button on a card: a copy format, "Open", and so on.
  component ClipPill: Rectangle {
    id: pill

    property string label: ""
    property bool main: false
    signal activated

    implicitWidth: pillText.implicitWidth + 22
    height: 24
    radius: 12
    color: main ? root.hot : pillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09)

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    Ink {
      id: pillText
      anchors.centerIn: parent
      text: pill.label
      font.pixelSize: Theme.smallSize + 1
      color: pill.main ? "#140f08" : root.ink
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.activated()
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
  readonly property real groupWidth: shape.width + (bubble.width > 0.5 ? bubble.width + 6 : 0) + (claudeSat.width > 0.5 ? claudeSat.width + 6 : 0) + (downloadSat.width > 0.5 ? downloadSat.width + 6 : 0) + dot.scale * 13 + micDot.scale * 14 + camDot.scale * 14

  // What takes input: the island and its satellites. Sized from where the
  // island is *going*, so the input region changes once per mode rather than
  // on every animation frame.
  readonly property real targetGroupWidth: size[0] + (bubbleShown ? compactH + 6 : 0) + (claudeBubbleShown ? compactH + 6 : 0) + (downloadBubbleShown ? compactH + 6 : 0) + tailTarget + (IdleInhibit.enabled ? 13 : 0) + (Privacy.micInUse ? 14 : 0) + (Privacy.camInUse ? 14 : 0)

  // Unread notifications: the island grows a section on its right with the
  // bell and a count. They never pop open on arrival; the bell just hops.
  // Only on the slim island — the big cards have their own layout.
  readonly property bool noteShown: Notifications.count > 0 && !Notifications.doNotDisturb && slim
  readonly property bool shelfShown: Shelf.count > 0 && slim
  readonly property real shelfTailTarget: shelfShown ? shelfRow.implicitWidth + 24 : 0
  readonly property real tailTarget: (noteShown ? noteRow.implicitWidth + 24 : 0) + shelfTailTarget
  property real shelfTailNow: shelfTailTarget
  Behavior on shelfTailNow {
    NumberAnimation {
      duration: root.morphMs
      easing.type: Easing.BezierSpline
      easing.bezierCurve: root.shapeCurve
    }
  }

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
    color: root.mode === "charging" ? root.good : root.mode === "player" ? root.tint : root.mode === "alert" || root.mode === "alertCard" ? root.alertColor : root.mode === "recording" ? "#f0808f" : root.mode === "claudeWaiting" ? "#f0c674" : root.hot
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
    opacity: root.mode === "charging" || root.mode === "thinking" || (root.mode === "alert" && root.settled) || (root.mode === "alertCard" && root.settled) || (root.mode === "recording" && root.settled) || (root.mode === "claudeWaiting" && root.settled) ? 0.7 : root.mode === "player" && root.settled && Media.hasCoverTint ? 0.42 : 0

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
        duration: root.quickResize ? 200 : root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.quickResize ? [0.2, 0.8, 0.2, 1, 1, 1] : root.shapeCurve
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: 380
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
      }
    }

    HoverHandler {
      id: islandHover
      onHoveredChanged: {
        if (hovered)
          peekDelay.restart();
        else
          root.cancelPeek();
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
      anchors.rightMargin: root.shelfTailNow
      y: 0
      width: root.tailNow - root.shelfTailNow
      height: parent.height
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
        active: Media.playing && root.activeKey === "music"
      }
    }

    // ---------------------------------------------------------- hover peek
    Layer {
      key: "peek"

      Item {
        id: peekSlot
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34

        Art {
          anchors.fill: parent
          visible: root.mode === "music"
          corner: 8
        }

        Ring {
          anchors.fill: parent
          visible: root.mode === "timer"
          thickness: 3
        }

        DownloadRing {
          anchors.fill: parent
          visible: root.mode === "download"
          thickness: 3
        }

        Ink {
          anchors.centerIn: parent
          visible: root.mode === "clock" || root.mode === "tone" || root.mode === "claude"
          text: root.mode === "clock" ? (Weather.ready ? Weather.glyph : Icons.calendar) : root.mode === "tone" ? Icons.sineWave : Icons.sparkle
          font.pixelSize: Theme.iconSize + 8
          color: root.hot
        }
      }

      Column {
        anchors.left: peekSlot.right
        anchors.leftMargin: 11
        anchors.right: peekEnd.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Ink {
          width: parent.width
          text: root.peekTitle
          font.bold: true
          textFormat: Text.PlainText
        }
        Item {
          width: parent.width
          height: peekSubText.implicitHeight

          readonly property bool showVolume: root.volumeShown && Moments.sink !== null

          Ink {
            id: peekSubText
            width: parent.width
            text: root.peekSub
            color: root.inkDim
            font.pixelSize: Theme.smallSize + 1
            textFormat: Text.PlainText
            opacity: parent.showVolume ? 0 : 1

            Behavior on opacity {
              NumberAnimation {
                duration: 140
              }
            }
          }

          // Takes the artist's place while you scroll the volume.
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            opacity: parent.showVolume ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: 140
              }
            }

            Ink {
              anchors.verticalCenter: parent.verticalCenter
              text: Icons.volHigh
              font.pixelSize: Theme.iconSize - 1
              color: root.hot
            }

            Rectangle {
              id: peekVolumeTrack
              anchors.verticalCenter: parent.verticalCenter
              width: 130
              height: 4
              radius: 2
              color: Qt.rgba(1, 1, 1, 0.16)

              Rectangle {
                height: parent.height
                radius: 2
                color: root.hot
                width: parent.width * Math.min(1, Moments.sink && Moments.sink.audio ? Moments.sink.audio.volume : 0)

                Behavior on width {
                  NumberAnimation {
                    duration: 120
                  }
                }
              }
            }

            Ink {
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round((Moments.sink && Moments.sink.audio ? Moments.sink.audio.volume : 0) * 100)
              color: root.inkDim
              font.pixelSize: Theme.smallSize + 1
            }
          }
        }
      }

      Item {
        id: peekEnd
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: root.mode === "music" ? peekSpectrum.width : peekRightText.implicitWidth
        height: parent.height

        Spectrum {
          id: peekSpectrum
          anchors.centerIn: parent
          visible: root.mode === "music"
          bars: 4
          maxHeight: 18
          color: root.tint
          active: Media.playing && root.activeKey === "peek" && root.mode === "music"
        }

        Ink {
          id: peekRightText
          anchors.centerIn: parent
          text: root.peekRight
          font.bold: true
          color: root.mode === "clock" ? root.ink : root.mode === "claude" ? root.inkDim : root.hot
        }
      }
    }

    // ------------------------------------------------------------ download
    Layer {
      key: "download"

      DownloadRing {
        id: downloadRing
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
      }

      Ink {
        anchors.left: downloadRing.right
        anchors.leftMargin: 8
        anchors.right: downloadPercent.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: Downloads.label
        textFormat: Text.PlainText
      }

      Ink {
        id: downloadPercent
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: Downloads.percent
        font.bold: true
        color: root.hot
      }
    }

    // -------------------------------------------------------- download done
    Layer {
      key: "downloaded"

      readonly property var m: root.moment && root.moment.kind === "downloaded" ? root.moment : null

      Rectangle {
        id: doneBadge
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 12
        color: root.hot

        Ink {
          anchors.centerIn: parent
          text: Icons.download
          font.pixelSize: Theme.iconSize + 5
          color: "#140f08"
        }
      }

      Column {
        anchors.left: doneBadge.right
        anchors.leftMargin: 12
        anchors.right: doneButtons.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Ink {
          width: parent.width
          text: parent.parent.m ? parent.parent.m.name : ""
          font.bold: true
          textFormat: Text.PlainText
          elide: Text.ElideMiddle
        }
        Ink {
          text: "Download finished"
          color: root.inkDim
          font.pixelSize: Theme.smallSize + 1
        }
      }

      Row {
        id: doneButtons
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 6

        Chip {
          label: "Open"
          strong: true
          onPressed: {
            Shelf.open(root.moment.path);
            Moments.dismiss();
          }
        }
        Chip {
          label: "Add to shelf"
          onPressed: {
            Shelf.addPaths([root.moment.path]);
            Moments.dismiss();
          }
        }
      }
    }

    // ---------------------------------------------------------- headphones
    Layer {
      id: headphonesLayer
      key: "headphones"

      // Held onto so the card doesn't blank while it shrinks away.
      property var device: null
      readonly property var live: root.moment && root.moment.kind === "headphones" ? root.moment.device : null
      onLiveChanged: if (live)
        device = live

      readonly property bool hasBattery: device ? device.batteryAvailable === true : false
      readonly property real battery: hasBattery ? device.battery : 0

      Ring {
        id: phonesRing
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        thickness: 3
        tone: headphonesLayer.battery < 0.2 ? "#f0808f" : root.good
        progress: 1 - headphonesLayer.battery
        scale: headphonesLayer.shown ? 1 : 0.6

        Behavior on scale {
          NumberAnimation {
            duration: 700
            easing.type: Easing.OutBack
            easing.overshoot: 1.8
          }
        }

        Ink {
          anchors.centerIn: parent
          text: Icons.forBluetoothDevice(headphonesLayer.device ? headphonesLayer.device.icon : "audio-headset")
          font.pixelSize: 24
        }
      }

      Column {
        anchors.left: phonesRing.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Ink {
          width: parent.width
          text: headphonesLayer.device ? (headphonesLayer.device.name || headphonesLayer.device.deviceName || "Headphones") : ""
          font.bold: true
          textFormat: Text.PlainText
        }
        Ink {
          width: parent.width
          text: headphonesLayer.hasBattery ? "Connected · " + Math.round(headphonesLayer.battery * 100) + "%" : "Connected"
          color: root.inkDim
          font.pixelSize: Theme.smallSize + 1
        }
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

    // ---------------------------------------------------------- claude
    Layer {
      key: "claude"

      Ink {
        id: claudeSpark
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.sparkle
        font.pixelSize: Theme.iconSize + 1
        color: root.hot

        SequentialAnimation on opacity {
          running: root.mode === "claude"
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.4
            duration: 800
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            to: 1
            duration: 800
            easing.type: Easing.InOutSine
          }
        }
      }

      Ink {
        anchors.left: claudeSpark.right
        anchors.leftMargin: 9
        anchors.right: claudeTime.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: ClaudeCode.working ? ClaudeCode.working.detail : ""
        textFormat: Text.PlainText
      }

      Ink {
        id: claudeTime
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: ClaudeCode.formatElapsed(root.claudeElapsed)
        color: root.inkDim
        font.pixelSize: Theme.smallSize + 1
      }
    }

    Layer {
      key: "claudeWaiting"

      Ink {
        id: waitSpark
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.sparkle
        font.pixelSize: Theme.iconSize + 1
        color: "#f0c674"
      }

      Ink {
        anchors.left: waitSpark.right
        anchors.leftMargin: 9
        anchors.right: waitProject.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: ClaudeCode.waiting ? "Claude · " + ClaudeCode.waiting.detail : ""
        textFormat: Text.PlainText
        font.bold: true
      }

      Ink {
        id: waitProject
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 110)
        text: ClaudeCode.waiting ? ClaudeCode.waiting.project : ""
        color: root.inkDim
        font.pixelSize: Theme.smallSize + 1
      }
    }

    // ------------------------------------------------------- recording
    Layer {
      key: "recording"

      Rectangle {
        id: recDot
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        radius: 5
        color: "#f0808f"

        SequentialAnimation on opacity {
          running: root.mode === "recording"
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.3
            duration: 700
          }
          NumberAnimation {
            to: 1
            duration: 700
          }
        }
      }

      Ink {
        anchors.left: recDot.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "Recording"
        font.bold: true
      }

      Ink {
        anchors.right: recStop.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Recorder.formatTime(Recorder.seconds)
        color: "#f0808f"
        font.bold: true
      }

      Ink {
        id: recStop
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.stop
        color: root.inkDim
      }
    }

    // ------------------------------------------------------------ drop
    Layer {
      key: "drop"

      Row {
        anchors.centerIn: parent
        spacing: 12

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.shelf
          font.pixelSize: 22
          color: root.hot
        }
        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: "Drop to keep it on the shelf"
          font.bold: true
        }
      }
    }

    // ----------------------------------------------------------- shelf
    Layer {
      key: "shelf"

      Column {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 12
        spacing: 6

        Item {
          width: parent.width
          height: 24

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: "Shelf"
            font.bold: true
          }

          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: shelfClearText.implicitWidth + 18
            height: 22
            radius: 11
            color: shelfClearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

            Ink {
              id: shelfClearText
              anchors.centerIn: parent
              text: "Clear"
              font.pixelSize: Theme.smallSize + 1
            }

            MouseArea {
              id: shelfClearArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Shelf.clear()
            }
          }
        }

        Repeater {
          model: Shelf.items.slice(0, 5)

          delegate: Rectangle {
            id: shelfRowItem

            required property var modelData

            width: parent.width
            height: 46
            radius: 13
            color: shelfArea.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06)

            // Drag this row out onto anything that takes files.
            Item {
              id: dragToken
              width: 1
              height: 1
              Drag.active: shelfArea.drag.active
              Drag.dragType: Drag.Automatic
              Drag.supportedActions: Qt.CopyAction
              Drag.mimeData: ({
                  "text/uri-list": "file://" + shelfRowItem.modelData.path + "\r\n"
                })
            }

            MouseArea {
              id: shelfArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              drag.target: dragToken
              onClicked: Shelf.open(shelfRowItem.modelData.path)
              drag.onActiveChanged: root.shelfDragging = drag.active
            }

            ClippingRectangle {
              id: shelfThumb
              x: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 32
              height: 32
              radius: 8
              color: Qt.rgba(1, 1, 1, 0.1)

              Image {
                anchors.fill: parent
                visible: shelfRowItem.modelData.image
                source: shelfRowItem.modelData.image ? "file://" + shelfRowItem.modelData.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 96
              }

              Ink {
                anchors.centerIn: parent
                visible: !shelfRowItem.modelData.image
                text: Icons.appFiles
                font.pixelSize: Theme.iconSize + 2
              }
            }

            Ink {
              anchors.left: shelfThumb.right
              anchors.leftMargin: 11
              anchors.right: shelfCopy.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: shelfRowItem.modelData.name
              textFormat: Text.PlainText
            }

            Rectangle {
              id: shelfCopy
              anchors.right: shelfRemove.left
              anchors.rightMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              width: 26
              height: 26
              radius: 13
              color: shelfCopyArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

              Ink {
                anchors.centerIn: parent
                text: Icons.copy
                font.pixelSize: Theme.iconSize - 1
              }

              MouseArea {
                id: shelfCopyArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Shelf.copy(shelfRowItem.modelData.path)
              }
            }

            Rectangle {
              id: shelfRemove
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 26
              height: 26
              radius: 13
              color: shelfRemoveArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

              Ink {
                anchors.centerIn: parent
                text: Icons.close
                font.pixelSize: Theme.smallSize + 1
                color: root.inkDim
              }

              MouseArea {
                id: shelfRemoveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Shelf.remove(shelfRowItem.modelData.path)
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- ask
    Layer {
      key: "ask"

      Item {
        id: askKeys
        anchors.fill: parent
        Keys.onEscapePressed: root.view = ""
      }

      Ink {
        id: askSpark
        x: 18
        y: 15
        text: Icons.sparkle
        font.pixelSize: Theme.iconSize + 1
        color: root.tint
      }

      Ink {
        anchors.left: askSpark.right
        anchors.leftMargin: 10
        anchors.right: askButtons.left
        anchors.rightMargin: 10
        y: 15
        text: root.question
        textFormat: Text.PlainText
        font.bold: true
      }

      Row {
        id: askButtons
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 11
        spacing: 6

        Repeater {
          model: ["Copy", "Open chat"]

          delegate: Rectangle {
            id: askBtn

            required property string modelData

            width: askBtnText.implicitWidth + 18
            height: 24
            radius: 12
            color: askBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

            Ink {
              id: askBtnText
              anchors.centerIn: parent
              text: askBtn.modelData
              font.pixelSize: Theme.smallSize + 1
            }

            MouseArea {
              id: askBtnArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (askBtn.modelData === "Copy") {
                  Clipboard.copy(root.answer);
                } else {
                  root.view = "";
                  if (!AiChat.open)
                    AiChat.toggle();
                }
              }
            }
          }
        }
      }

      Flickable {
        x: 18
        y: 48
        width: parent.width - 36
        height: parent.height - 48 - 16
        contentHeight: askBody.implicitHeight
        contentY: Math.max(0, contentHeight - height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Text {
          id: askBody
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.MarkdownText
          text: root.answer.length > 0 ? root.answer : "Thinking…"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: AiChat.error ? "#f0808f" : root.answer.length > 0 ? root.ink : root.inkDim
        }
      }
    }

    // ------------------------------------------------------- shelf tail
    Item {
      id: shelfTail

      anchors.right: parent.right
      y: 0
      width: root.shelfTailNow
      height: parent.height
      opacity: root.shelfShown ? 1 : 0
      visible: width > 0.5

      Behavior on opacity {
        NumberAnimation {
          duration: 260
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: Qt.rgba(1, 1, 1, 0.14)
      }

      Row {
        id: shelfRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 1
        spacing: 5

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.shelf
          color: root.hot
        }
        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: Shelf.count
          font.bold: true
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Moments.dismiss();
          root.view = "shelf";
        }
      }
    }

    // Files dragged over the island land on the shelf.
    DropArea {
      anchors.fill: parent
      keys: ["text/uri-list"]
      onEntered: root.dragOver = true
      onExited: root.dragOver = false
      onDropped: drop => {
        root.dragOver = false;
        if (drop.hasUrls) {
          Shelf.addUrls(drop.urls);
          drop.accept(Qt.CopyAction);
        }
      }
    }

    // ------------------------------------------------------------- alert
    Layer {
      key: "alert"

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          text: root.alertData ? root.alertData.glyph : ""
          font.pixelSize: Theme.iconSize
          color: root.alertColor
        }
        Ink {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 80
          text: root.alertData ? root.alertData.label : ""
          font.bold: true
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: alertValue.implicitWidth + 16
          height: 18
          radius: 9
          color: root.alertColor

          Ink {
            id: alertValue
            anchors.centerIn: parent
            text: root.alertData ? root.alertData.value : ""
            font.pixelSize: Theme.smallSize
            font.bold: true
            color: "#140f08"
          }
        }
      }
    }

    Layer {
      key: "alertCard"

      Column {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 14
        spacing: 9

        Row {
          width: parent.width
          spacing: 10

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: root.alertData ? root.alertData.glyph : ""
            font.pixelSize: Theme.iconSize + 3
            color: root.alertColor
          }
          Ink {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 90
            text: root.alertData ? root.alertData.label : ""
            font.bold: true
            font.pixelSize: Theme.fontSize + 1
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: cardValue.implicitWidth + 16
            height: 18
            radius: 9
            color: root.alertColor

            Ink {
              id: cardValue
              anchors.centerIn: parent
              text: root.alertData ? root.alertData.value : ""
              font.pixelSize: Theme.smallSize
              font.bold: true
              color: "#140f08"
            }
          }
        }

        Ink {
          width: parent.width
          text: root.alertData && root.alertData.detail ? root.alertData.detail : " "
          color: root.inkDim
          font.pixelSize: Theme.smallSize + 1
        }

        Row {
          spacing: 6

          Repeater {
            model: root.alertData && root.alertData.action ? ["Open System", "Dismiss"] : ["Dismiss"]

            delegate: Rectangle {
              id: alertBtn

              required property string modelData

              width: alertBtnText.implicitWidth + 24
              height: 26
              radius: 13
              color: alertBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)

              Ink {
                id: alertBtnText
                anchors.centerIn: parent
                text: alertBtn.modelData
                font.pixelSize: Theme.smallSize + 1
              }

              MouseArea {
                id: alertBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  const action = alertBtn.modelData === "Dismiss" ? "" : root.alertData.action;
                  root.view = "";
                  if (action)
                    Moments.popupRequested(action, root.screenName());
                }
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------------- today
    // The time, weather, a month you can flip through, your market symbols,
    // and the focus timer. Scroll to walk through days, or click one.
    Layer {
      id: todayLayer
      key: "today"

      Item {
        anchors.fill: parent
        anchors.margins: 16
        anchors.leftMargin: 18
        anchors.rightMargin: 18

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

        Row {
          visible: Weather.ready
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 4
          spacing: 10

          Ink {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.glyph
            font.pixelSize: 26
            color: root.hot
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter

            Ink {
              anchors.right: parent.right
              text: Weather.tempC + "°"
              font.bold: true
              font.pixelSize: 18
            }
            Ink {
              anchors.right: parent.right
              text: Weather.place
              color: root.inkDim
              font.pixelSize: Theme.smallSize
            }
          }
        }

        // Month title and arrows.
        Item {
          id: monthBar
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: todayTime.bottom
          anchors.topMargin: 10
          height: 26

          Ink {
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.shownMonth, "MMMM yyyy")
            font.bold: true
          }

          Repeater {
            model: [
              {
                glyph: Icons.chevronLeft,
                step: -1
              },
              {
                glyph: Icons.chevronRight,
                step: 1
              }
            ]

            delegate: Rectangle {
              id: monthArrow

              required property var modelData

              x: modelData.step < 0 ? 0 : monthBar.width - width
              width: 26
              height: 26
              radius: 13
              color: monthArrowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

              Ink {
                anchors.centerIn: parent
                text: monthArrow.modelData.glyph
                font.pixelSize: Theme.iconSize
              }

              MouseArea {
                id: monthArrowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.monthOffset += monthArrow.modelData.step
              }
            }
          }
        }

        Grid {
          id: monthGrid
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: monthBar.bottom
          anchors.topMargin: 4
          columns: 7

          readonly property real cellWidth: width / 7

          Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            delegate: Item {
              required property string modelData

              width: monthGrid.cellWidth
              height: 18

              Ink {
                anchors.centerIn: parent
                text: parent.modelData
                color: root.inkDim
                font.pixelSize: Theme.smallSize
              }
            }
          }

          Repeater {
            model: root.monthDays

            delegate: Item {
              id: dateCell

              required property var modelData

              width: monthGrid.cellWidth
              height: 29

              Rectangle {
                anchors.centerIn: parent
                width: 27
                height: 27
                radius: 13.5
                color: dateCell.modelData.today ? root.hot : dateArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                border.width: dateCell.modelData.picked && !dateCell.modelData.today ? 1.5 : 0
                border.color: root.hot

                Ink {
                  anchors.centerIn: parent
                  text: dateCell.modelData.day
                  font.bold: dateCell.modelData.today
                  color: dateCell.modelData.today ? "#140f08" : dateCell.modelData.inMonth ? root.ink : Qt.rgba(0.96, 0.94, 0.89, 0.28)
                }
              }

              MouseArea {
                id: dateArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dayOffset = dateCell.modelData.offset
              }
            }
          }
        }

        // Market symbols from the Dashboard, drifting past.
        Rectangle {
          id: ticker
          visible: Dashboard.stocks.length > 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: monthGrid.bottom
          anchors.topMargin: 10
          height: 28
          radius: 14
          color: Qt.rgba(1, 1, 1, 0.07)
          clip: true

          component TickerRow: Row {
            spacing: 26
            y: (28 - height) / 2

            Repeater {
              model: Dashboard.stocks.filter(q => q.price !== undefined && q.previous)

              delegate: Row {
                id: quote

                required property var modelData
                readonly property real change: Dashboard.changePercent(modelData)

                spacing: 6

                Ink {
                  text: quote.modelData.symbol
                  font.pixelSize: Theme.smallSize + 1
                }
                Ink {
                  text: (quote.change >= 0 ? "+" : "") + quote.change.toFixed(1) + "%"
                  font.pixelSize: Theme.smallSize + 1
                  color: quote.change >= 0 ? root.good : "#f0808f"
                }
              }
            }
          }

          Item {
            id: tape
            height: parent.height
            property real span: firstRow.implicitWidth + 26

            NumberAnimation on x {
              running: root.mode === "today" && tape.span > 30
              loops: Animation.Infinite
              from: 14
              to: 14 - tape.span
              duration: Math.max(4000, tape.span * 42)
            }

            TickerRow {
              id: firstRow
            }
            TickerRow {
              x: tape.span
            }
            TickerRow {
              x: tape.span * 2
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
                NumberAnimation {
                  duration: 260
                  easing.type: Easing.BezierSpline
                  easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
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

        // Three lines at a time; the song's position scrolls them.
        Item {
          visible: Lyrics.available
          width: parent.width
          height: 64
          clip: true

          Column {
            width: parent.width
            y: 21 - Math.max(0, Lyrics.currentIndex) * 22

            Behavior on y {
              NumberAnimation {
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
              }
            }

            Repeater {
              model: root.mode === "player" ? Lyrics.lines : []

              delegate: Item {
                id: lyric

                required property var modelData
                required property int index
                readonly property bool current: index === Lyrics.currentIndex

                width: parent.width
                height: 22

                Ink {
                  anchors.centerIn: parent
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: lyric.modelData.text
                  textFormat: Text.PlainText
                  font.bold: lyric.current
                  color: lyric.current ? root.tint : root.inkDim
                  opacity: Math.abs(lyric.index - Lyrics.currentIndex) > 1 ? 0 : 1

                  Behavior on color {
                    ColorAnimation {
                      duration: 300
                    }
                  }
                  Behavior on opacity {
                    NumberAnimation {
                      duration: 300
                    }
                  }
                }
              }
            }
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
    // ------------------------------------------------------------- clipboard
    // What was just copied. Everything it shows is built in Moments.qml.
    Layer {
      id: clipLayer
      key: "clip"

      readonly property var m: root.moment && root.moment.kind === "clip" ? root.moment : null
      // Kept so the text does not vanish while the card is folding away.
      property var held: null
      onMChanged: {
        if (m)
          held = m;
      }
      readonly property var d: m ?? held

      // The card waits while the pointer is on it.
      HoverHandler {
        onHoveredChanged: Moments.hold(hovered)
      }

      Item {
        id: clipHead
        x: 16
        y: clipLayer.d && clipLayer.d.pills.length === 0 && !clipLayer.d.note ? (parent.height - height) / 2 : 12
        width: parent.width - 32
        height: 26

        Rectangle {
          id: clipMark
          visible: clipLayer.d ? (clipLayer.d.swatch !== undefined || clipLayer.d.badge !== undefined) : false
          width: visible ? 26 : 0
          height: 26
          radius: 8
          color: !clipLayer.d ? "transparent" : clipLayer.d.swatch ? clipLayer.d.swatch : clipLayer.d.tone === "good" ? root.good : clipLayer.d.tone === "dim" ? Qt.rgba(1, 1, 1, 0.12) : root.hot
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.18)

          Ink {
            anchors.centerIn: parent
            visible: clipLayer.d && !clipLayer.d.swatch
            text: clipLayer.d && clipLayer.d.badge ? clipLayer.d.badge : ""
            font.bold: true
            color: clipLayer.d && clipLayer.d.tone === "dim" ? root.inkDim : "#140f08"
          }
        }

        Ink {
          id: clipTitle
          anchors.left: clipMark.right
          anchors.leftMargin: clipMark.visible ? 12 : 0
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, clipHead.width - clipMark.width - (clipMark.visible ? 12 : 0) - clipSide.implicitWidth - 20 - clipDim.implicitWidth)
          text: clipLayer.d ? clipLayer.d.title : ""
          textFormat: Text.PlainText
          font.bold: true
          font.pixelSize: clipLayer.d && clipLayer.d.type === "unit" ? Theme.fontSize + 5 : Theme.fontSize + 1
        }

        Ink {
          id: clipDim
          anchors.left: clipTitle.right
          anchors.leftMargin: 5
          anchors.verticalCenter: parent.verticalCenter
          visible: text.length > 0
          text: clipLayer.d && clipLayer.d.titleDim ? clipLayer.d.titleDim : ""
          textFormat: Text.PlainText
          color: root.inkDim
          width: Math.min(implicitWidth, Math.max(0, clipHead.width - clipMark.width - clipTitle.width - clipSide.implicitWidth - 40))
        }

        Ink {
          id: clipSide
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: clipLayer.d && clipLayer.d.side ? clipLayer.d.side : ""
          color: root.inkDim
          font.pixelSize: Theme.smallSize
        }
      }

      Row {
        x: 16
        y: 12 + 26 + 8
        spacing: 8
        visible: clipLayer.d ? clipLayer.d.pills.length > 0 : false

        Repeater {
          model: clipLayer.d ? clipLayer.d.pills : []

          delegate: ClipPill {
            required property var modelData

            label: modelData.label
            main: modelData.main === true
            onActivated: {
              if (modelData.copy !== undefined) {
                Clipboard.copy(modelData.copy);
              } else if (modelData.open !== undefined) {
                Quickshell.execDetached(["xdg-open", modelData.open]);
                Moments.dismiss();
              }
            }
          }
        }

        Ink {
          anchors.verticalCenter: parent.verticalCenter
          visible: clipLayer.d && clipLayer.d.note ? clipLayer.d.note.length > 0 : false
          text: clipLayer.d && clipLayer.d.note ? clipLayer.d.note : ""
          color: root.inkDim
          font.pixelSize: Theme.smallSize + 1
        }
      }

      // Text and secret copies have no buttons; the note sits under the title.
      Ink {
        x: 16
        y: 12 + 26 + 6
        width: parent.width - 32
        visible: clipLayer.d ? clipLayer.d.pills.length === 0 && !!clipLayer.d.note : false
        text: clipLayer.d && clipLayer.d.note ? clipLayer.d.note : ""
        color: root.inkDim
        font.pixelSize: Theme.smallSize + 1
      }
    }

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
            text: root.moment && root.moment.title ? root.moment.title : "Screenshot saved"
            font.bold: true
          }
          Ink {
            text: root.moment && root.moment.sub ? root.moment.sub : "Copied · click to open"
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

  // Claude busy while music or something else holds the island.
  Rectangle {
    id: claudeSat

    x: (root.bubbleShown ? bubble.x + bubble.width : shape.x + shape.width) + (root.claudeBubbleShown ? 6 : 0)
    y: shape.y
    width: root.claudeBubbleShown ? root.compactH : 0
    height: root.compactH
    radius: height / 2
    color: "#050403"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    clip: true
    opacity: root.claudeBubbleShown ? 1 : 0
    visible: opacity > 0.01

    Behavior on width {
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: 220
      }
    }

    Ink {
      anchors.centerIn: parent
      text: Icons.sparkle
      font.pixelSize: Theme.iconSize + 1
      color: root.hot

      RotationAnimation on rotation {
        running: root.claudeBubbleShown
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 2400
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (ClaudeCode.working)
          ClaudeCode.focus(ClaudeCode.working.window);
      }
    }
  }

  // A download while something else holds the island.
  Rectangle {
    id: downloadSat

    x: (root.claudeBubbleShown ? claudeSat.x + claudeSat.width : root.bubbleShown ? bubble.x + bubble.width : shape.x + shape.width) + (root.downloadBubbleShown ? 6 : 0)
    y: shape.y
    width: root.downloadBubbleShown ? root.compactH : 0
    height: root.compactH
    radius: height / 2
    color: "#050403"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    clip: true
    opacity: root.downloadBubbleShown ? 1 : 0
    visible: opacity > 0.01

    Behavior on width {
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: 220
      }
    }

    DownloadRing {
      anchors.centerIn: parent
      width: 18
      height: 18
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Downloads.openFolder()
    }
  }

  // A green dot while something records the mic, orange for the camera. Hover
  // to see which app.
  component PrivacyDot: Rectangle {
    id: pdot

    property bool on: false
    property string label: ""

    y: shape.y + (root.compactH - height) / 2
    width: 8
    height: 8
    radius: 4
    scale: on ? 1 : 0
    visible: scale > 0.01

    Behavior on scale {
      NumberAnimation {
        duration: 500
        easing.type: Easing.OutBack
        easing.overshoot: 2
      }
    }

    MouseArea {
      id: pdotArea
      anchors.fill: parent
      anchors.margins: -5
      hoverEnabled: true
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 18
      width: pdotLabel.implicitWidth + 20
      height: 24
      radius: 10
      color: "#050403"
      opacity: pdotArea.containsMouse ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: 140
        }
      }

      Ink {
        id: pdotLabel
        anchors.centerIn: parent
        text: pdot.label
        font.pixelSize: Theme.smallSize + 1
      }
    }
  }

  PrivacyDot {
    id: micDot
    x: (IdleInhibit.enabled ? dot.x + dot.width : root.bubblesRight) + 6
    color: "#8ad79a"
    on: Privacy.micInUse
    label: "Microphone · " + Privacy.micApps.join(", ")
  }

  PrivacyDot {
    id: camDot
    x: micDot.x + (Privacy.micInUse ? micDot.width + 6 : 0)
    color: "#F59A6E"
    on: Privacy.camInUse
    label: "Camera · " + Privacy.camApps.join(", ")
  }

  // Keep awake: a small breathing dot beside the island, like a privacy light.
  Rectangle {
    id: dot

    x: root.bubblesRight + 6
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
