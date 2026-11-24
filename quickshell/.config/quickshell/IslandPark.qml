pragma Singleton

// IslandPark.qml — the island TV. A window parked in the island keeps running
// there as a small live screen, on every workspace.
//
// YouTube: when a video starts playing in a browser, the island says SUPER+I
// puts it on the TV. SUPER+I then parks that browser window (focused or not)
// and makes the video fill the little screen: the window is told it is
// fullscreen (Hyprland keeps its size) and YouTube gets its own `f` key.
// Sending it back undoes both. Firefox's picture-in-picture window flies in by
// itself. Anything else: SUPER+I parks the focused window (an mpv window, say).
// SUPER+I again, or the island's return button, sends it back.
//
// Hover the island and it grows into a bigger screen with the player's
// controls over the picture (DynamicIsland's "park" layer). The controls drive
// the window's own MPRIS player, the same media controls the island uses for
// music.
//
// Hyprland only draws a window that is on screen, and a capture of a window it
// doesn't draw goes black (on a hidden workspace, or moved fully off-screen).
// So the parked window is not hidden away: it is floated, pinned, sized to the
// island's screen and pushed up until all but a 2px sliver is above the top
// edge, nearly transparent (the island-tv window rule in hyprland.lua). That
// still counts as on screen, so the app keeps drawing, and the island shows a
// live ScreencopyView of it. The hidden window is always the big size and the
// small island shows it scaled down: resizing a captured window ends the
// capture, so nothing is resized once the picture is up.
//
// Parking: the window shrinks into the island's pill and fades out on the
// way, then the island morphs into the TV and the picture fades in.
// Unparking runs it backwards: the picture fades, the island folds into its
// pill, and the window grows back out of it to where it was.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Singleton {
  id: root

  // The screen's size at rest and while hovered (16:9, like most video); the
  // island adds a black frame around it (DynamicIsland's sizeFor("park")).
  readonly property int smallW: 256
  readonly property int smallH: 144
  readonly property int bigW: 512
  readonly property int bigH: 288
  readonly property int frame: 5
  readonly property int radius: 16

  property bool expanded: false
  readonly property int width: expanded ? bigW : smallW
  readonly property int height: expanded ? bigH : smallH

  // "" when nothing is parked; set as soon as parking starts.
  property string address: ""
  // The island is grown to the screen.
  property bool shown: false
  // The hidden window has its final size: the island may capture it.
  property bool ready: false
  property bool busy: false
  // Where the window was, to send it back there.
  property var saved: null
  property string windowClass: ""
  // The parked window is a YouTube page, made to fill the screen.
  property bool youtube: false

  // ------------------------------------------------------------ YouTube
  readonly property var browserClass: /firefox|chrom|brave|zen|librewolf|vivaldi|floorp/i

  // A browser window showing YouTube, while a browser is playing something.
  readonly property var youtubeWindow: {
    const players = Mpris.players ? Array.from(Mpris.players.values) : [];
    const playing = players.some(p => p.isPlaying && browserClass.test([p.desktopEntry, p.identity, p.dbusName].join(" ")));
    if (!playing)
      return null;
    const wins = Hyprland.toplevels.values.filter(t => {
      const o = t.lastIpcObject;
      const cls = (o && o.class) || (t.wayland ? t.wayland.appId : "");
      return browserClass.test(cls) && /YouTube/.test(t.title) && t.title !== "Picture-in-Picture";
    });
    return wins.find(t => t.activated) ?? wins[0] ?? null;
  }

  // Say once per video that it can go on the TV.
  property string announced: ""
  readonly property string youtubeKey: youtubeWindow && address === "" ? youtubeWindow.title : ""
  onYoutubeKeyChanged: {
    if (youtubeKey === "" || youtubeKey === announced)
      return;
    announced = youtubeKey;
    Moments.toast(Icons.tv, "Watch on the little TV", "SUPER+I", true, 3500);
  }

  readonly property var hyprWindow: address === "" ? null : Hyprland.toplevels.values.find(t => bare(t.address) === bare(root.address)) ?? null
  // The Wayland handle the ScreencopyView captures.
  readonly property var toplevel: hyprWindow ? hyprWindow.wayland : null
  readonly property string title: hyprWindow ? hyprWindow.title : ""

  // The parked window's media player, for the controls: matched by app.
  readonly property var player: {
    if (windowClass === "" || !Mpris.players)
      return null;
    const c = windowClass.toLowerCase();
    const all = Array.from(Mpris.players.values);
    const mine = all.filter(p => {
      const ids = [p.desktopEntry, p.identity, p.dbusName].map(s => String(s ?? "").toLowerCase());
      return ids.some(s => s.length > 0 && (s.includes(c) || c.includes(s.split(".").pop())));
    });
    return mine.find(p => p.isPlaying) ?? mine[0] ?? null;
  }

  // MPRIS position only refreshes when asked.
  Timer {
    running: root.shown && root.expanded && root.player !== null && root.player.isPlaying
    interval: 500
    repeat: true
    onTriggered: root.player.positionChanged()
  }

  function bare(a) {
    return String(a ?? "").replace(/^0x/, "");
  }

  function win() {
    return "window = \"address:0x" + bare(root.address) + "\"";
  }

  function dispatch(lua) {
    Hyprland.dispatch(lua);
  }

  // The island's top-left on the focused screen, where the window flies to.
  function spot(w) {
    const m = Hyprland.focusedMonitor;
    const mx = m && m.lastIpcObject ? m.lastIpcObject.x : 0;
    const mw = m ? m.width / (m.scale || 1) : 1280;
    return {
      x: Math.round(mx + (mw - w) / 2),
      y: Math.round((Theme.barHeight - 26) / 2) + root.frame
    };
  }

  function toggle() {
    if (busy)
      return;
    if (address !== "")
      unpark();
    else if (youtubeWindow) {
      clientQuery.want = youtubeWindow.address;
      clientQuery.running = true;
    } else
      activeQuery.running = true;
  }

  // Quickshell's cached window info lacks the geometry until refreshed, so ask
  // Hyprland directly.
  Process {
    id: activeQuery
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.park(JSON.parse(text));
        } catch (e) {}
      }
    }
  }

  Process {
    id: clientQuery
    property string want: ""
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const c = JSON.parse(text).find(w => root.bare(w.address) === root.bare(clientQuery.want));
          if (c)
            root.park(c);
        } catch (e) {}
      }
    }
  }

  function park(o) {
    if (busy || address !== "" || !o || !o.address || o.class === "island-term" || o.fullscreen)
      return;
    busy = true;
    expanded = false;
    address = o.address;
    windowClass = o.class ?? "";
    youtube = browserClass.test(windowClass) && /YouTube/.test(o.title ?? "");
    saved = {
      floating: o.floating,
      at: o.at,
      size: o.size,
      workspace: o.workspace ? o.workspace.id : -1
    };
    // Into the pill: the window shrinks onto the island's centre and fades out
    // on the way (the islandtv rule), as if the island swallows it.
    const c = pour();
    root.dispatch("hl.dsp.window.float({ action = \"enable\", " + win() + " })");
    root.dispatch("hl.dsp.window.tag({ tag = \"+islandtv-frame\", " + win() + " })");
    root.dispatch("hl.dsp.window.tag({ tag = \"+islandtv\", " + win() + " })");
    root.dispatch("hl.dsp.window.resize({ x = " + root.pourW + ", y = " + root.pourH + ", " + win() + " })");
    root.dispatch("hl.dsp.window.move({ x = " + c.x + ", y = " + c.y + ", " + win() + " })");
    root.dispatch("hl.dsp.window.pin({ action = \"enable\", " + win() + " })");
    parkHide.restart();
  }

  // The size and spot the window shrinks to as it goes into the pill.
  readonly property int pourW: 112
  readonly property int pourH: 63
  function pour() {
    const s = spot(root.pourW);
    return {
      x: s.x,
      y: Math.round(Theme.barHeight / 2 - root.pourH / 2)
    };
  }

  // Swallowed: the island morphs into the TV while the (invisible) window
  // takes its real size above the screen's edge and, for YouTube, fills it
  // with the video. The picture fades in once that has settled.
  Timer {
    id: parkHide
    interval: 380
    onTriggered: {
      const s = root.spot(root.bigW);
      const w = root.win();
      root.shown = true;
      root.dispatch("hl.dsp.window.resize({ x = " + root.bigW + ", y = " + root.bigH + ", " + w + " })");
      root.dispatch("hl.dsp.window.move({ x = " + s.x + ", y = " + (2 - root.bigH) + ", " + w + " })");
      if (root.youtube) {
        // The browser thinks it's fullscreen (no tabs or toolbar) at the same
        // size, then YouTube's own `f` fills it with the video. A pinned window
        // can't really go fullscreen (binds:allow_pin_fullscreen), so it can't
        // take the whole screen either.
        root.dispatch("hl.dsp.window.fullscreen_state({ internal = 0, client = 2, " + w + " })");
        fillKey.restart();
      }
      parkReady.interval = root.youtube ? 950 : 350;
      parkReady.restart();
    }
  }

  Timer {
    id: fillKey
    interval: 300
    onTriggered: root.dispatch("hl.dsp.send_shortcut({ mods = \"\", key = \"f\", " + root.win() + " })")
  }

  Timer {
    id: parkReady
    onTriggered: {
      root.ready = true;
      root.busy = false;
    }
  }

  // Back out: the picture fades, the island morphs back into its pill, and the
  // window comes out of it, growing and fading in, to where it was.
  function unpark() {
    if (address === "" || busy)
      return;
    busy = true;
    expanded = false;
    ready = false;
    shown = false;
    fillKey.stop();
    if (youtube) {
      // YouTube leaves its fullscreen, then the browser its own, while hidden.
      // The browser restores its own size as it leaves fullscreen, so wait for
      // that before moving it.
      root.dispatch("hl.dsp.send_shortcut({ mods = \"\", key = \"f\", " + win() + " })");
      unfill.restart();
      unparkPlace.interval = 700;
    } else {
      unparkPlace.interval = 380;
    }
    unparkPlace.restart();
  }

  Timer {
    id: unfill
    interval: 200
    onTriggered: root.dispatch("hl.dsp.window.fullscreen_state({ internal = 0, client = 0, " + root.win() + " })")
  }

  // Still invisible, into the pill's centre at the small size.
  Timer {
    id: unparkPlace
    interval: 380
    onTriggered: {
      const c = root.pour();
      root.dispatch("hl.dsp.window.resize({ x = " + root.pourW + ", y = " + root.pourH + ", " + root.win() + " })");
      root.dispatch("hl.dsp.window.move({ x = " + c.x + ", y = " + c.y + ", " + root.win() + " })");
      unparkOut.restart();
    }
  }

  // Out of the pill: visible again and back to its place.
  Timer {
    id: unparkOut
    interval: 120
    onTriggered: {
      const w = root.win();
      const sv = root.saved;
      root.dispatch("hl.dsp.window.tag({ tag = \"-islandtv\", " + w + " })");
      root.dispatch("hl.dsp.window.pin({ action = \"disable\", " + w + " })");
      if (sv && sv.floating) {
        root.dispatch("hl.dsp.window.resize({ x = " + sv.size[0] + ", y = " + sv.size[1] + ", " + w + " })");
        root.dispatch("hl.dsp.window.move({ x = " + sv.at[0] + ", y = " + sv.at[1] + ", " + w + " })");
      } else {
        root.dispatch("hl.dsp.window.float({ action = \"disable\", " + w + " })");
      }
      root.dispatch("hl.dsp.focus({ " + w + " })");
      unparkDone.restart();
    }
  }

  // Landed: its border and shadow come back, and anything that didn't take
  // (a browser leaving fullscreen can undo a move) is put right.
  Timer {
    id: unparkDone
    interval: 500
    onTriggered: {
      root.dispatch("hl.dsp.window.tag({ tag = \"-islandtv-frame\", " + root.win() + " })");
      landedCheck.want = root.address;
      landedCheck.sv = root.saved;
      landedCheck.running = true;
      root.forget();
    }
  }

  Process {
    id: landedCheck
    property string want: ""
    property var sv: null
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        let c = null;
        try {
          c = JSON.parse(text).find(w => root.bare(w.address) === root.bare(landedCheck.want));
        } catch (e) {}
        const sv = landedCheck.sv;
        if (!c || !sv)
          return;
        const w = "window = \"address:0x" + root.bare(landedCheck.want) + "\"";
        if (c.pinned)
          root.dispatch("hl.dsp.window.pin({ action = \"disable\", " + w + " })");
        for (const t of (c.tags ?? []).filter(t => t.startsWith("islandtv")))
          root.dispatch("hl.dsp.window.tag({ tag = \"-" + t + "\", " + w + " })");
        if (!sv.floating && c.floating)
          root.dispatch("hl.dsp.window.float({ action = \"disable\", " + w + " })");
        else if (sv.floating && (c.at[0] !== sv.at[0] || c.at[1] !== sv.at[1])) {
          root.dispatch("hl.dsp.window.resize({ x = " + sv.size[0] + ", y = " + sv.size[1] + ", " + w + " })");
          root.dispatch("hl.dsp.window.move({ x = " + sv.at[0] + ", y = " + sv.at[1] + ", " + w + " })");
        }
      }
    }
  }

  function forget() {
    parkHide.stop();
    parkReady.stop();
    fillKey.stop();
    unfill.stop();
    unparkPlace.stop();
    unparkOut.stop();
    unparkDone.stop();
    root.ready = false;
    root.youtube = false;
    root.shown = false;
    root.expanded = false;
    root.address = "";
    root.windowClass = "";
    root.saved = null;
    root.busy = false;
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      // The parked window closed by itself (the video ended, PiP closed): the
      // island just folds back.
      if (event.name === "closewindow") {
        if (root.address !== "" && root.bare(event.data) === root.bare(root.address))
          root.forget();
        return;
      }
      // Firefox's picture-in-picture window goes straight into the island.
      // openwindow carries ADDRESS,WORKSPACE,CLASS,TITLE.
      if (event.name === "openwindow" && root.address === "") {
        const parts = event.data.split(",");
        if (parts.length >= 4 && parts.slice(3).join(",") === "Picture-in-Picture") {
          clientQuery.want = parts[0];
          pipDelay.restart();
        }
      }
    }
  }

  // Give the new window a moment to get its size before it flies.
  Timer {
    id: pipDelay
    interval: 250
    onTriggered: clientQuery.running = true
  }

  IpcHandler {
    target: "islandpark"

    function toggle(): void {
      root.toggle();
    }
    function expand(on: bool): void {
      root.expanded = on;
    }
    function state(): string {
      return JSON.stringify({
        address: root.address,
        shown: root.shown,
        expanded: root.expanded,
        youtube: root.youtube,
        youtubeWindow: root.youtubeWindow ? root.youtubeWindow.title : null,
        player: root.player ? root.player.identity : null
      });
    }
  }

  GlobalShortcut {
    appid: "quickshell"
    name: "islandPark"
    description: "Park the focused window in the island as a little TV (again sends it back)"
    onPressed: root.toggle()
  }
}
