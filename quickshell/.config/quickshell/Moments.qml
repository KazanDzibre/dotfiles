pragma Singleton

// Moments.qml — what the island in the middle of the bar should be showing.
//
// Two kinds of thing reach the island:
//
// - moments: brief takeovers that come and go on their own (volume moved,
//   Bluetooth switched off, a notification, a screenshot, a new wallpaper's
//   palette, the charger plugged in). Only one at a time; a newer one replaces
//   the old. `moment` holds it as { kind, ... } and clears itself.
// - live activities: things that are true for a while (music playing, a focus
//   timer, the AI answering, updates installing, keep awake). Those are read
//   straight from their own singletons by DynamicIsland.qml, not stored here.
//
// Everything below just watches the rest of the shell and turns changes into
// moments. Nothing fires for the first few seconds after startup, while every
// service is still reporting its initial state.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick

Singleton {
  id: root

  property var moment: null

  // Startup grace: services report their first values as "changes".
  property bool ready: false

  // Ask a bar to open one of its panels; the screen name keeps it to the screen
  // the island was clicked on.
  signal popupRequested(string name, string screenName)

  function show(data, ms) {
    if (!root.ready)
      return;
    root.moment = data;
    expire.interval = ms ?? 1800;
    expire.restart();
  }

  function dismiss() {
    expire.stop();
    root.moment = null;
  }

  Timer {
    id: expire
    onTriggered: root.moment = null
  }

  Timer {
    running: true
    interval: 4000
    onTriggered: root.ready = true
  }

  function toast(glyph, label, state, on, ms) {
    root.show({
      kind: "toast",
      glyph: glyph,
      label: label,
      state: state,
      on: on
    }, ms ?? 1600);
  }

  function level(which, value) {
    root.show({
      kind: "level",
      which: which,
      value: Math.max(0, Math.min(1, value))
    }, 1400);
  }

  // ------------------------------------------------------------------ volume
  readonly property var sink: Pipewire.defaultAudioSink

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  Connections {
    target: root.sink ? root.sink.audio : null

    function onVolumeChanged() {
      root.level(root.sink.audio.muted ? "mute" : "volume", root.sink.audio.volume);
    }

    function onMutedChanged() {
      root.level(root.sink.audio.muted ? "mute" : "volume", root.sink.audio.volume);
    }
  }

  // -------------------------------------------------------------- brightness
  // Backlight also polls for changes made elsewhere (the brightness keys), so
  // those show up here too.
  Connections {
    target: Backlight

    function onBrightnessChanged() {
      if (Backlight.brightnessAvailable)
        root.level("brightness", Backlight.brightness);
    }

    function onTemperatureChanged() {
      if (Backlight.temperatureAvailable)
        root.level("warmth", (Backlight.neutralTemperature - Backlight.temperature) / (Backlight.neutralTemperature - Backlight.warmestTemperature));
    }
  }

  // ----------------------------------------------------------------- toggles
  Connections {
    target: Networking

    function onWifiEnabledChanged() {
      root.toast(Networking.wifiEnabled ? Icons.wifiRamp[4] : Icons.wifiOff, "Wi-Fi", Networking.wifiEnabled ? "ON" : "OFF", Networking.wifiEnabled);
    }
  }

  Connections {
    target: Bluetooth.defaultAdapter

    function onEnabledChanged() {
      const on = Bluetooth.defaultAdapter.enabled;
      root.toast(on ? Icons.bluetooth : Icons.bluetoothOff, "Bluetooth", on ? "ON" : "OFF", on);
    }
  }

  Connections {
    target: IdleInhibit

    function onEnabledChanged() {
      root.toast(IdleInhibit.enabled ? Icons.coffee : Icons.coffeeOff, "Keep awake", IdleInhibit.enabled ? "ON" : "OFF", IdleInhibit.enabled);
    }
  }

  Connections {
    target: Notifications

    function onDoNotDisturbChanged() {
      root.toast(Notifications.doNotDisturb ? Icons.bellOff : Icons.bell, "Do not disturb", Notifications.doNotDisturb ? "ON" : "OFF", Notifications.doNotDisturb);
    }
  }

  Connections {
    target: Theme

    function onModeChanged() {
      root.toast(Theme.isLight ? Icons.sun : Icons.moon, Theme.isLight ? "Light mode" : "Dark mode", "ON", true);
    }
  }

  // ----------------------------------------------------------- notifications
  // Screenshot.qml announces itself through notify-send with the image as the
  // icon, so a screenshot arrives here too and gets its own thumbnail moment.
  Connections {
    target: Notifications

    function onArrived(notification) {
      if (notification.appName === "Screenshot") {
        root.show({
          kind: "shot",
          // The saved file, not the notification's image (an in-memory
          // image:// URL nothing outside Quickshell can open).
          image: Screenshot.lastPath
        }, 3600);
        return;
      }
      // Everything else just updates the count beside the island (see
      // DynamicIsland.qml); popping a card open for each one was too noisy.
    }
  }

  // --------------------------------------------------------------- wallpaper
  // Once waypaper is done (pywal has re-themed by then), show the new palette.
  // Delayed so it lands after the reveal animation rather than on top of it.
  Connections {
    target: Wallpaper

    function onApplyingChanged() {
      if (!Wallpaper.applying)
        paletteDelay.restart();
    }
  }

  Timer {
    id: paletteDelay
    interval: 900
    onTriggered: root.show({
      kind: "palette",
      colors: Wallpaper.paletteFor(Wallpaper.current).length > 0 ? Wallpaper.paletteFor(Wallpaper.current) : [Theme.walBg, Theme.c1, Theme.c3, Theme.accent, Theme.walFg]
    }, 2800)
  }

  // ----------------------------------------------------------------- battery
  readonly property var battery: UPower.displayDevice
  readonly property bool charging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false
  readonly property int batteryPercent: {
    if (!battery)
      return 0;
    const raw = battery.percentage;
    return Math.round(raw <= 1.0 ? raw * 100 : raw);
  }

  onChargingChanged: {
    if (charging)
      root.show({
        kind: "charging"
      }, 2600);
    else
      root.toast(Icons.batteryRamp[Math.max(0, Math.min(10, Math.round(root.batteryPercent / 10)))], "On battery", root.batteryPercent + "%", false);
  }

  // -------------------------------------------------------------- headphones
  // The card holds the device itself, because the battery often shows up a
  // moment after the connection does.
  readonly property var audioDevices: Bluetooth.devices ? Array.from(Bluetooth.devices.values).filter(d => d.connected && /audio|head/i.test(d.icon ?? "")) : []
  property var knownAudio: []

  onAudioDevicesChanged: {
    const fresh = root.audioDevices.filter(d => !root.knownAudio.includes(d.address));
    root.knownAudio = root.audioDevices.map(d => d.address);
    if (fresh.length === 0 || !root.ready)
      return;
    root.show({
      kind: "headphones",
      device: fresh[0]
    }, 4500);
    Sounds.play("connect");
  }

  // --------------------------------------------------------------- downloads
  Connections {
    target: Downloads

    function onFinished(name, path) {
      root.show({
        kind: "downloaded",
        name: name,
        path: path
      }, 7000);
      Sounds.play("download");
    }
  }

  // ------------------------------------------------------------------ sounds
  Connections {
    target: Sounds

    function onEnabledChanged() {
      root.toast(Sounds.enabled ? Icons.volHigh : Icons.volMute, "Island sounds", Sounds.enabled ? "ON" : "OFF", Sounds.enabled);
    }
  }

  // ------------------------------------------------------------- Claude Code
  property string lastWaiting: ""

  Connections {
    target: ClaudeCode

    // Each hook replaces the session object, so go by id: one chime per wait.
    function onWaitingChanged() {
      const id = ClaudeCode.waiting ? ClaudeCode.waiting.id : "";
      if (id && id !== root.lastWaiting && root.ready)
        Sounds.play("attention");
      root.lastWaiting = id;
    }

    function onFinished(session, failed, seconds) {
      // Quick replies aren't worth interrupting for.
      if (seconds < 15 && !failed)
        return;
      Sounds.play(failed ? "alert" : "complete");
      root.show({
        kind: "toast",
        glyph: Icons.sparkle,
        label: failed ? "Claude stopped with an error" : "Claude finished",
        state: ClaudeCode.formatElapsed(seconds),
        on: !failed,
        window: session.window
      }, 5000);
    }
  }

  // --------------------------------------------------------------- recording
  Connections {
    target: Recorder

    function onFinished(path, thumbnail) {
      root.show({
        kind: "shot",
        image: thumbnail,
        open: path,
        title: "Recording saved",
        sub: "Click to open"
      }, 5000);
    }

    function onMissing(tool) {
      root.toast(Icons.record, "Install " + tool + " first", "MISSING", false, 3500);
    }
  }

  // ---------------------------------------------------------------- calendar
  Connections {
    target: Calendar

    function onStarting(event) {
      root.show({
        kind: "meeting",
        event: event
      }, 90000);
      Sounds.play("attention");
    }
  }

  // ------------------------------------------------------------------- notes
  Connections {
    target: Notes

    function onSaved(text) {
      root.toast(Icons.note, "Note saved", Notes.open + (Notes.open === 1 ? " NOTE" : " NOTES"), true, 1800);
    }

    function onReminder(text, time) {
      root.show({
        kind: "reminder",
        text: text,
        time: time
      }, 15000);
      Sounds.play("attention");
    }
  }

  // ------------------------------------------------------------ screen tools
  // A picked colour arrives through the clipboard peek; only failure lands here.
  Connections {
    target: ScreenTools

    function onMissing(tool) {
      root.toast(Icons.eyedropper, "Install " + tool + " first", "MISSING", false, 3500);
    }
  }

  // ------------------------------------------------------------------ health
  // Only when something is wrong, and only once per incident: an alert re-arms
  // after the value has properly recovered. CPU and memory also have to stay
  // high for a few readings, so a brief spike says nothing.
  property var over: ({})
  property var fired: ({})

  function watch(key, value, trip, recover, needed, raise) {
    if (!root.ready)
      return;
    if (value < recover) {
      root.over[key] = 0;
      root.fired[key] = false;
      return;
    }
    if (value < trip)
      return;
    root.over[key] = (root.over[key] ?? 0) + 1;
    if (!root.fired[key] && root.over[key] >= needed) {
      root.fired[key] = true;
      raise();
    }
  }

  function alert(data) {
    Sounds.play("alert");
    root.show(Object.assign({
      kind: "alert"
    }, data), 6500);
  }

  // Names what's responsible before showing the alert.
  property var pendingAlert: null

  function alertWithTop(data, sortBy, describe) {
    root.pendingAlert = {
      data: data,
      describe: describe
    };
    topProcess.exec(["sh", "-c", "ps -eo comm=,pcpu=,rss= --sort=-" + sortBy + " | head -1"]);
  }

  Process {
    id: topProcess
    stdout: StdioCollector {
      onStreamFinished: {
        const p = root.pendingAlert;
        if (!p)
          return;
        const f = text.trim().split(/\s+/);
        const rss = Number(f[f.length - 1]);
        const pcpu = f[f.length - 2];
        const name = f.slice(0, -2).join(" ");
        root.alert(Object.assign({}, p.data, {
          detail: name ? p.describe(name, pcpu, rss) : ""
        }));
        root.pendingAlert = null;
      }
    }
  }

  Connections {
    target: SysInfo

    function onCpuTempChanged() {
      root.watch("cpu", SysInfo.cpuTemp, 90, 80, 3, () => root.alertWithTop({
        glyph: Icons.thermometer,
        label: "CPU running hot",
        value: Math.round(SysInfo.cpuTemp) + "°C",
        crit: true,
        action: "system"
      }, "pcpu", (name, pcpu) => "Busiest process: " + name + ", using " + pcpu + "% of a core."));
    }

    function onMemoryChanged() {
      root.watch("memory", SysInfo.memory, 0.9, 0.82, 3, () => root.alertWithTop({
        glyph: Icons.memory,
        label: "Memory running out",
        value: Math.round(SysInfo.memory * 100) + "%",
        crit: true,
        action: "system"
      }, "rss", (name, pcpu, rss) => "Biggest user: " + name + ", at " + (rss / 1048576).toFixed(1) + " GB."));
    }

    function onDiskChanged() {
      root.watch("disk", SysInfo.disk, 0.9, 0.85, 1, () => root.alert({
        glyph: Icons.disk,
        label: "Disk almost full",
        value: Math.round(SysInfo.disk * 100) + "%",
        crit: SysInfo.disk >= 0.95,
        detail: "Root drive has " + Math.round(SysInfo.diskTotalGb - SysInfo.diskUsedGb) + " GB free.",
        action: "system"
      }));
    }
  }

  // Low is the bad direction here, so it's watched as "how far gone".
  function checkBattery() {
    if (root.charging || !root.battery || !root.battery.isPresent) {
      root.over.battery = 0;
      root.fired.battery = false;
      root.fired.batteryCrit = false;
      return;
    }
    const raise = crit => () => root.alert({
          glyph: Icons.batteryAlert,
          label: "Battery low",
          value: root.batteryPercent + "%",
          crit: crit,
          detail: root.battery.timeToEmpty > 0 ? "About " + Math.round(root.battery.timeToEmpty / 60) + " minutes left at this rate." : "",
          action: ""
        });
    root.watch("battery", 100 - root.batteryPercent, 80, 70, 1, raise(false));
    root.watch("batteryCrit", 100 - root.batteryPercent, 90, 85, 1, raise(true));
  }

  onBatteryPercentChanged: root.checkBattery()

  // ---------------------------------------------------------------------- AI
  // When an answer finishes while the panel is closed, offer a peek at it.
  Connections {
    target: AiChat

    function onStreamingChanged() {
      if (AiChat.streaming || AiChat.open)
        return;
      const last = AiChat.messages.length > 0 ? AiChat.messages[AiChat.messages.length - 1] : null;
      if (!last || last.role !== "assistant")
        return;
      root.show({
        kind: "answer",
        text: String(last.content).replace(/\s+/g, " ").trim()
      }, 4500);
    }
  }

  // ----------------------------------------------------------------- updates
  // While installing, the island shows it as a live activity on its own.
  Connections {
    target: Updates

    function onInstallingChanged() {
      if (!Updates.installing)
        root.toast(Icons.upToDate, "Updates finished", "DONE", true, 2200);
    }

    function onUpToDate() {
      root.toast(Icons.upToDate, "System up to date", "DONE", true);
    }
  }

  // ------------------------------------------------------------------- tones
  Connections {
    target: Tones

    function onPlayingChanged() {
      if (Tones.playing > 0)
        root.toast(Icons.sineWave, Tones.nameFor(Tones.playing) + " · " + Tones.playing + " Hz", "ON", true);
      else
        root.toast(Icons.sineWave, "Tone", "OFF", false);
    }

    function onTimingChanged() {
      if (Tones.timing && Tones.timerLeft === Tones.timerTotal)
        root.toast(Icons.timer, "Focus · " + Math.round(Tones.timerTotal / 60) + " min", "START", true);
    }
  }

  // -------------------------------------------------------------- caps lock
  // Say so when it flips, so a password isn't typed in capitals by accident.
  // The first report is the starting state, which `show` drops during startup.
  Process {
    running: true
    command: ["python3", Quickshell.shellPath("scripts/capslock.py")]

    stdout: SplitParser {
      onRead: line => {
        const on = line.trim() === "1";
        root.toast(Icons.keyboard, "Caps Lock", on ? "ON" : "OFF", on, 1400);
      }
    }
  }

  // ------------------------------------------------------------ panels & apps
  Connections {
    target: AiAssistant

    function onShownChanged() {
      root.toast(Icons.ai, AiAssistant.name, AiAssistant.shown ? "OPEN" : "HIDDEN", AiAssistant.shown, 1200);
    }
  }

  Connections {
    target: AiChat

    function onOpenChanged() {
      root.toast(Icons.ai, "AI chat", AiChat.open ? "OPEN" : "CLOSED", AiChat.open, 1200);
    }
  }

  Connections {
    target: Dashboard

    function onOpenChanged() {
      root.toast(Icons.dashboard, "Dashboard", Dashboard.open ? "OPEN" : "CLOSED", Dashboard.open, 1200);
    }
  }

  Connections {
    target: Clipboard

    function onCopied(text) {
      const flat = String(text).replace(/\s+/g, " ").trim();
      root.toast(Icons.copy, flat.length > 26 ? flat.substring(0, 25) + "…" : flat, "COPIED", true);
    }
  }

  // --------------------------------------------------------------- clipboard
  // Something was copied: show what it is, in a form that fits. A colour gets
  // its other formats, a link its clean version, a file its folder, a number
  // with a unit its conversion. DynamicIsland.qml only draws what is built here
  // (the "clip" layer renders `pills`), so a new kind of copy is a change to
  // this file alone.
  //
  // Plain text is the common case and the noisiest; turn it off to peek only
  // for the kinds that have something to offer.
  readonly property bool clipPeekText: true
  readonly property int clipMs: 2800

  // For hover: stay while the pointer is on the card, restart the clock after.
  function hold(on) {
    if (!root.moment)
      return;
    if (on)
      expire.stop();
    else
      expire.restart();
  }

  function clipShow(data) {
    root.show(Object.assign({
      kind: "clip"
    }, data), root.clipMs);
  }

  function hex2(n) {
    return (n < 16 ? "0" : "") + n.toString(16);
  }

  function toHsl(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
    let h = 0, s = 0;
    if (mx !== mn) {
      const d = mx - mn;
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h *= 60;
    }
    return [Math.round(h), Math.round(s * 100), Math.round(l * 100)];
  }

  function colorMoment(r, g, b) {
    const hex = "#" + root.hex2(r) + root.hex2(g) + root.hex2(b);
    const rgb = "rgb(" + r + ", " + g + ", " + b + ")";
    const h = root.toHsl(r, g, b);
    const hsl = "hsl(" + h[0] + ", " + h[1] + "%, " + h[2] + "%)";
    return {
      type: "color",
      swatch: hex,
      title: hex,
      side: "colour",
      pills: [
        {
          label: "hex",
          copy: hex
        },
        {
          label: rgb,
          copy: rgb
        },
        {
          label: hsl,
          copy: hsl
        }
      ]
    };
  }

  // Tracking parameters that only exist to say where you clicked from.
  readonly property var trackingParam: /^(utm_[a-z]+|fbclid|gclid|dclid|msclkid|mc_[a-z]+|igshid|yclid|_hsenc|_hsmi|ref_src|ref_url|si)$/i

  function linkMoment(url) {
    const m = url.match(/^(https?):\/\/([^\/?#\s]+)([^?#\s]*)(\?[^#\s]*)?(#\S*)?$/i);
    if (!m)
      return null;
    const domain = m[2].replace(/^www\./i, "");
    const path = m[3] === "/" ? "" : m[3];
    const params = m[4] ? m[4].substring(1).split("&") : [];
    const kept = params.filter(p => !root.trackingParam.test(p.split("=")[0]));
    const removed = params.length - kept.length;
    const clean = m[1] + "://" + m[2] + m[3] + (kept.length > 0 ? "?" + kept.join("&") : "") + (m[5] ?? "");
    const pills = [
      {
        label: "Open",
        open: url,
        main: true
      }
    ];
    if (removed > 0) {
      pills.push({
        label: "Copy clean link",
        copy: clean
      });
    }
    return {
      type: "link",
      badge: domain.charAt(0).toUpperCase(),
      tone: "accent",
      title: domain,
      titleDim: path.length > 28 ? path.substring(0, 27) + "…" : path,
      side: "link",
      note: removed > 0 ? removed + " tracking param" + (removed > 1 ? "s" : "") + " removed" : "",
      pills: pills
    };
  }

  function pathMoment(text) {
    const home = Quickshell.env("HOME");
    const full = text.startsWith("~/") ? home + text.substring(1) : text;
    const slash = full.lastIndexOf("/");
    const name = full.substring(slash + 1) || full;
    const folder = slash > 0 ? full.substring(0, slash) : "/";
    return {
      type: "file",
      badge: "F",
      tone: "good",
      title: name,
      side: "file",
      note: folder.replace(home, "~"),
      pills: [
        {
          label: "Open folder",
          open: folder,
          main: true
        }
      ]
    };
  }

  function textMoment(text) {
    const first = text.trim().split("\n")[0];
    const words = text.trim().split(/\s+/).length;
    const lines = text.split("\n").length;
    return {
      type: "text",
      title: first.length > 58 ? first.substring(0, 57) + "…" : first,
      note: text.length + " characters · " + words + (words === 1 ? " word" : " words") + (lines > 1 ? " · " + lines + " lines" : ""),
      pills: []
    };
  }

  // Each unit's counterpart in the other system, for the conversion shown.
  readonly property var counterpart: ({
      km: "mi",
      mi: "km",
      kg: "lb",
      lb: "kg",
      lbs: "kg",
      cm: "in",
      in: "cm",
      ft: "m",
      m: "ft",
      l: "gal",
      gal: "l",
      oz: "g",
      g: "oz",
      "°c": "°f",
      "°f": "°c"
    })

  property string unitText: ""
  Process {
    id: unitProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const a = JSON.parse(text);
          if (!a.title)
            return;
          root.clipShow({
            type: "unit",
            title: root.unitText + " " + a.title,
            side: "conversion",
            pills: [
              {
                label: "Copy " + a.value,
                copy: a.value
              }
            ]
          });
        } catch (e) {}
      }
    }
  }

  Connections {
    target: Clipboard

    function onArrived(text, sensitive) {
      if (!root.ready)
        return;
      if (sensitive) {
        root.clipShow({
          type: "secret",
          badge: "●",
          tone: "dim",
          title: "Copied · hidden",
          side: "from password manager",
          pills: []
        });
        return;
      }
      const t = text.trim();
      const single = t.indexOf("\n") < 0;
      let m;

      if (single && (m = t.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i))) {
        let h = m[1];
        if (h.length === 3)
          h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        const n = parseInt(h, 16);
        root.clipShow(root.colorMoment((n >> 16) & 255, (n >> 8) & 255, n & 255));
        return;
      }
      if (single && (m = t.match(/^rgba?\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})/i)) && m[1] <= 255 && m[2] <= 255 && m[3] <= 255) {
        root.clipShow(root.colorMoment(+m[1], +m[2], +m[3]));
        return;
      }
      if (single && /^https?:\/\//i.test(t)) {
        const link = root.linkMoment(t);
        if (link) {
          root.clipShow(link);
          return;
        }
      }
      if (single && /^(~\/|\/)[^\n]{1,300}$/.test(t) && t.length > 2) {
        root.clipShow(root.pathMoment(t));
        return;
      }
      if (single && (m = t.match(/^(-?[\d.,]+)\s*(km|mi|kg|lbs?|cm|in|ft|m|l|gal|oz|g|°c|°f)$/i)) && root.counterpart[m[2].toLowerCase()]) {
        root.unitText = m[1] + " " + m[2];
        unitProc.command = ["python3", Quickshell.shellPath("scripts/answer.py"), m[1] + " " + m[2] + " in " + root.counterpart[m[2].toLowerCase()]];
        unitProc.running = true;
        return;
      }
      if (root.clipPeekText && t.length >= 3)
        root.clipShow(root.textMoment(text));
    }
  }

  // ------------------------------------------------------------------ drives
  property int driveCount: Drives.drives.length

  onDriveCountChanged: {
    if (root.driveCount > root.lastDriveCount)
      root.toast(Icons.usbDrive, "USB drive connected", "NEW", true, 2200);
    else if (root.driveCount < root.lastDriveCount)
      root.toast(Icons.eject, "USB drive removed", "OFF", false);
    root.lastDriveCount = root.driveCount;
  }
  property int lastDriveCount: 0

  Connections {
    target: Drives

    function onEjectingChanged() {
      if (Drives.ejecting.length > 0)
        root.toast(Icons.eject, "Ejecting drive…", "WAIT", true, 1500);
    }
  }

  // ------------------------------------------------------------- focus timer
  Connections {
    target: Tones

    function onTimerFinished() {
      Sounds.play("complete");
      root.toast(Icons.timer, "Focus session done", "DONE", true, 3500);
    }
  }
}
