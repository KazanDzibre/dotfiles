pragma Singleton

// Weather.qml — current conditions for the island's Today card, from wttr.in.
//
// Novi Sad unless QS_WEATHER_CITY names somewhere else. (Left to itself,
// wttr.in guesses from the IP address and lands on Belgrade.) Checked every
// half hour.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string city: Quickshell.env("QS_WEATHER_CITY") || "Novi Sad"

  property bool ready: false
  property int tempC: 0
  property string place: ""
  property string description: ""
  property int code: 0

  readonly property string glyph: {
    const c = root.code;
    if (c === 113)
      return Icons.weatherSunny;
    if (c === 116)
      return Icons.weatherPartly;
    if (c === 119 || c === 122)
      return Icons.weatherCloudy;
    if ([143, 248, 260].includes(c))
      return Icons.weatherFog;
    if ([200, 386, 389, 392, 395].includes(c))
      return Icons.weatherLightning;
    if ([179, 182, 185, 227, 230, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(c))
      return Icons.weatherSnowy;
    return Icons.weatherRainy;
  }

  function refresh() {
    if (!fetcher.running)
      fetcher.running = true;
  }

  Timer {
    running: true
    repeat: true
    interval: 30 * 60 * 1000
    onTriggered: root.refresh()
  }

  // A moment after startup, so it doesn't compete with everything else.
  Timer {
    running: true
    interval: 2500
    onTriggered: root.refresh()
  }

  Process {
    id: fetcher
    command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(root.city) + "?format=j1"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          const now = data.current_condition[0];
          root.tempC = Number(now.temp_C);
          root.code = Number(now.weatherCode);
          root.description = now.weatherDesc[0].value;
          root.place = root.city.length > 0 ? root.city : data.nearest_area[0].areaName[0].value;
          root.ready = true;
        } catch (e) {
          // Offline or a bad reply: keep whatever was showing.
        }
      }
    }
  }
}
