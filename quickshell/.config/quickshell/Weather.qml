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

  // The rest of what wttr.in sends, for the island's weather card.
  property int feelsC: 0
  property int humidity: 0
  property int windKmh: 0
  property string windDir: ""
  property int uv: 0
  property int pressure: 0
  property int highC: 0
  property int lowC: 0
  property string sunrise: ""
  property string sunset: ""
  // The next few three-hour slots, today's first and then tomorrow's:
  // { label: "15:00", tempC, code, rain } (rain is a percentage).
  property var hours: []

  readonly property string glyph: root.glyphFor(root.code)

  function glyphFor(c) {
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

  // "06:35 AM" -> "06:35".
  function clock24(text) {
    const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)$/i.exec(text ?? "");
    if (!m)
      return text ?? "";
    const h = (Number(m[1]) % 12) + (m[3].toUpperCase() === "PM" ? 12 : 0);
    return String(h).padStart(2, "0") + ":" + m[2];
  }

  function upcoming(days) {
    const now = new Date();
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const out = [];
    days.forEach((day, d) => {
      for (const h of day.hourly) {
        const t = Number(h.time);
        const minutes = Math.floor(t / 100) * 60 + (t % 100);
        // A slot covers the three hours from its time, so keep the current one.
        if (d === 0 && minutes + 180 <= nowMinutes)
          continue;
        out.push({
          label: String(Math.floor(t / 100)).padStart(2, "0") + ":00",
          tempC: Number(h.tempC),
          code: Number(h.weatherCode),
          rain: Number(h.chanceofrain)
        });
      }
    });
    return out.slice(0, 7);
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
          root.feelsC = Number(now.FeelsLikeC);
          root.humidity = Number(now.humidity);
          root.windKmh = Number(now.windspeedKmph);
          root.windDir = now.winddir16Point;
          root.uv = Number(now.uvIndex);
          root.pressure = Number(now.pressure);
          const today = data.weather[0];
          root.highC = Number(today.maxtempC);
          root.lowC = Number(today.mintempC);
          root.sunrise = root.clock24(today.astronomy[0].sunrise);
          root.sunset = root.clock24(today.astronomy[0].sunset);
          root.hours = root.upcoming(data.weather);
          root.place = root.city.length > 0 ? root.city : data.nearest_area[0].areaName[0].value;
          root.ready = true;
        } catch (e) {
          // Offline or a bad reply: keep whatever was showing.
        }
      }
    }
  }
}
