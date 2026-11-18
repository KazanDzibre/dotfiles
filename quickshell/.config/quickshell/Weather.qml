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

  // The week ahead from Open-Meteo: { label, code (WMO), hiC, loC, rain }.
  property var days: []

  // Open-Meteo reports WMO codes, not wttr.in's.
  function glyphForWmo(c) {
    if (c === 0)
      return Icons.weatherSunny;
    if (c === 1 || c === 2)
      return Icons.weatherPartly;
    if (c === 3)
      return Icons.weatherCloudy;
    if (c === 45 || c === 48)
      return Icons.weatherFog;
    if (c >= 95)
      return Icons.weatherLightning;
    if ((c >= 71 && c <= 77) || c === 85 || c === 86)
      return Icons.weatherSnowy;
    return Icons.weatherRainy;
  }

  // Air quality (US AQI) from Open-Meteo, looked up for the spot wttr.in
  // resolved the city to. -1 until it arrives.
  property int aqi: -1
  property real pm25: 0
  property real pm10: 0
  property string lat: ""
  property string lon: ""

  // The US AQI bands: green, yellow, orange, red, purple, maroon.
  readonly property var aqiBands: [
    {
      max: 50,
      label: "Good",
      color: "#4cc46a"
    },
    {
      max: 100,
      label: "Moderate",
      color: "#f2d24b"
    },
    {
      max: 150,
      label: "Unhealthy for sensitive",
      color: "#f29a3d"
    },
    {
      max: 200,
      label: "Unhealthy",
      color: "#e5504b"
    },
    {
      max: 300,
      label: "Very unhealthy",
      color: "#a661d6"
    },
    {
      max: 100000,
      label: "Hazardous",
      color: "#8a2f45"
    }
  ]
  readonly property var aqiBand: {
    for (const b of root.aqiBands) {
      if (root.aqi <= b.max)
        return b;
    }
    return root.aqiBands[root.aqiBands.length - 1];
  }

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
          root.lat = data.nearest_area[0].latitude;
          root.lon = data.nearest_area[0].longitude;
          root.ready = true;
          if (!airFetcher.running)
            airFetcher.running = true;
          if (!weekFetcher.running)
            weekFetcher.running = true;
        } catch (e) {
          // Offline or a bad reply: keep whatever was showing.
        }
      }
    }
  }

  Process {
    id: airFetcher
    command: ["curl", "-sf", "--max-time", "15", "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + root.lat + "&longitude=" + root.lon + "&current=us_aqi,pm2_5,pm10"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const cur = JSON.parse(text).current;
          if (cur.us_aqi === null || cur.us_aqi === undefined)
            return;
          root.aqi = Math.round(cur.us_aqi);
          root.pm25 = cur.pm2_5;
          root.pm10 = cur.pm10;
        } catch (e) {
          // Offline or no data for this spot: the row just stays hidden.
        }
      }
    }
  }

  Process {
    id: weekFetcher
    command: ["curl", "-sf", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text).daily;
          const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
          root.days = d.time.map((t, i) => ({
                label: i === 0 ? "Today" : names[new Date(t + "T12:00:00").getDay()],
                code: d.weather_code[i],
                hiC: Math.round(d.temperature_2m_max[i]),
                loC: Math.round(d.temperature_2m_min[i]),
                rain: d.precipitation_probability_max[i] ?? 0
              }));
        } catch (e) {
          // Offline: the Weekly view just stays empty.
        }
      }
    }
  }
}
