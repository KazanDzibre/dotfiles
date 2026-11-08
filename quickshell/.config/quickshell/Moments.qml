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
      root.toast(Icons.timer, "Focus session done", "DONE", true, 3500);
    }
  }
}
