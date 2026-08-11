// Backlight.qml — screen brightness and colour temperature.
//
// Brightness goes through brightnessctl, which writes /sys/class/backlight
// without root. A polling loop keeps us in sync with the XF86MonBrightness
// keys, which change the backlight behind our back.
//
// Colour temperature goes through hyprsunset. That is an optional package; if
// it isn't installed the warmth control reports itself unavailable rather than
// silently doing nothing.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // ------------------------------------------------------------- brightness
  property real brightness: 0        // 0..1
  property bool brightnessAvailable: false

  // While the user drags, the poll must not yank the slider back to a value
  // read before our write landed.
  property bool holdPoll: false

  Timer {
    id: releaseHold
    interval: 1500
    onTriggered: root.holdPoll = false
  }

  Process {
    running: true
    command: ["sh", "-c", "while true; do brightnessctl -m 2>/dev/null | awk -F, '{ gsub(\"%\",\"\",$4); print $4 }'; sleep 2; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const pct = parseFloat(line.trim());
        if (isNaN(pct))
          return;
        root.brightnessAvailable = true;
        if (!root.holdPoll)
          root.brightness = Math.max(0, Math.min(1, pct / 100));
      }
    }
  }

  Process {
    id: brightnessSetter
  }

  // Dragging emits far more updates than we want processes for, so the newest
  // value is applied on a 60ms heartbeat instead of once per pixel.
  property real pendingBrightness: -1

  Timer {
    id: brightnessThrottle
    interval: 60
    onTriggered: {
      if (root.pendingBrightness < 0)
        return;
      // Never all the way to zero — a black screen with no way back is not a
      // state a slider should be able to reach.
      const pct = Math.round(Math.max(0.01, Math.min(1, root.pendingBrightness)) * 100);
      root.pendingBrightness = -1;
      brightnessSetter.command = ["brightnessctl", "-q", "set", pct + "%"];
      brightnessSetter.startDetached();
    }
  }

  function setBrightness(value) {
    root.brightness = Math.max(0.01, Math.min(1, value));
    root.pendingBrightness = root.brightness;
    root.holdPoll = true;
    releaseHold.restart();
    if (!brightnessThrottle.running)
      brightnessThrottle.start();
  }

  // ------------------------------------------------------------ temperature
  readonly property int neutralTemperature: 6500
  readonly property int warmestTemperature: 1000

  property int temperature: 6500
  property bool temperatureAvailable: false

  Process {
    running: true
    command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes || echo no"]

    stdout: StdioCollector {
      onStreamFinished: root.temperatureAvailable = text.trim() === "yes"
    }
  }

  // Remembers where the slider was. Deliberately not re-applied on startup:
  // hyprsunset's own state is the truth about the screen, and silently
  // re-tinting the display because the bar restarted would be wrong.
  FileView {
    id: temperatureFile
    path: Quickshell.cachePath("screen-temperature")

    onLoaded: {
      const saved = parseInt(text().trim());
      if (!isNaN(saved) && saved >= root.warmestTemperature && saved <= root.neutralTemperature)
        root.temperature = saved;
    }
    onLoadFailed: Qt.callLater(() => temperatureFile.setText(String(root.temperature)))
  }

  Process {
    id: temperatureSetter
  }

  property int pendingTemperature: -1

  Timer {
    id: temperatureThrottle
    interval: 90
    onTriggered: {
      if (root.pendingTemperature < 0)
        return;
      const kelvin = root.pendingTemperature;
      root.pendingTemperature = -1;

      // Talk to a running hyprsunset over Hyprland's IPC; if the daemon isn't
      // up yet, start it with the requested temperature.
      const cmd = kelvin >= root.neutralTemperature ? "hyprctl hyprsunset identity >/dev/null 2>&1 || true" : "hyprctl hyprsunset temperature " + kelvin + " >/dev/null 2>&1 || (nohup hyprsunset -t " + kelvin + " >/dev/null 2>&1 &)";

      temperatureSetter.command = ["sh", "-c", cmd];
      temperatureSetter.startDetached();
      temperatureFile.setText(String(kelvin));
    }
  }

  function setTemperature(kelvin) {
    root.temperature = Math.round(Math.max(root.warmestTemperature, Math.min(root.neutralTemperature, kelvin)));
    root.pendingTemperature = root.temperature;
    if (!temperatureThrottle.running)
      temperatureThrottle.start();
  }

  // Tanner Helland's blackbody approximation — good enough to tint a slider.
  function kelvinToColor(kelvin) {
    const t = kelvin / 100;
    let r, g, b;

    r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
    g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
    b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;

    const clamp = v => Math.max(0, Math.min(255, v)) / 255;
    return Qt.rgba(clamp(r), clamp(g), clamp(b), 1.0);
  }
}
