// WeatherBackdrop.qml — the sky behind the island's weather card: a sunny
// glow, drifting clouds, rain, snow, fog or lightning, in day or night colours,
// chosen from the wttr.in weather code. Kept dark and soft so the light text on
// top stays readable. Its animations only run while it is visible, i.e. while
// the card is open.
import QtQuick
import qs

Rectangle {
  id: root

  // wttr.in weatherCode, and whether the sun is down.
  property int code: 113
  property bool night: false

  readonly property string kind: {
    const c = root.code;
    if (c === 113)
      return "clear";
    if (c === 116)
      return "partly";
    if (c === 119 || c === 122)
      return "cloudy";
    if ([143, 248, 260].includes(c))
      return "fog";
    if ([200, 386, 389, 392, 395].includes(c))
      return "storm";
    if ([179, 182, 185, 227, 230, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(c))
      return "snow";
    return "rain";
  }
  readonly property bool gloomy: ["cloudy", "fog", "storm", "snow", "rain"].includes(kind)

  // A repeatable "random" number from an index, so the drops don't move in step.
  function rnd(i, k) {
    const x = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - Math.floor(x);
  }

  clip: true
  gradient: Gradient {
    GradientStop {
      position: 0
      color: root.night ? (root.gloomy ? "#1a2230" : "#0e1830") : root.gloomy ? "#3a4656" : "#2f6aa3"
    }
    GradientStop {
      position: 1
      color: root.night ? (root.gloomy ? "#10151d" : "#0a0f1d") : root.gloomy ? "#232c38" : "#1c3b63"
    }
  }

  // Stars, for a clear or part-clear night.
  Repeater {
    model: root.night && (root.kind === "clear" || root.kind === "partly") ? 26 : 0

    delegate: Rectangle {
      required property int index

      x: root.rnd(index, 1) * root.width
      y: root.rnd(index, 2) * root.height * 0.7
      width: 1 + Math.round(root.rnd(index, 3) * 1.4)
      height: width
      radius: width / 2
      color: "white"
      opacity: 0.5

      SequentialAnimation on opacity {
        running: root.visible
        loops: Animation.Infinite
        PauseAnimation {
          duration: root.rnd(index, 4) * 2500
        }
        NumberAnimation {
          to: 0.15
          duration: 1200 + root.rnd(index, 5) * 1500
        }
        NumberAnimation {
          to: 0.8
          duration: 1200 + root.rnd(index, 6) * 1500
        }
      }
    }
  }

  // The sun by day, the moon by night: a few soft rings around a bright disc.
  Item {
    visible: root.kind === "clear" || root.kind === "partly"
    x: root.width * 0.78
    y: root.height * 0.2
    width: 1
    height: 1

    Repeater {
      model: 5

      delegate: Rectangle {
        required property int index
        readonly property real size: 46 + index * 46

        x: -size / 2
        y: -size / 2
        width: size
        height: size
        radius: size / 2
        color: root.night ? "#cfd8ff" : "#ffd27a"
        opacity: index === 0 ? (root.night ? 0.9 : 0.95) : 0.11 - index * 0.018
      }
    }

    SequentialAnimation on scale {
      running: root.visible
      loops: Animation.Infinite
      NumberAnimation {
        to: 1.06
        duration: 3200
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1
        duration: 3200
        easing.type: Easing.InOutSine
      }
    }
  }

  // Clouds: drift right to left and wrap.
  Repeater {
    model: root.kind === "partly" ? 3 : root.kind === "clear" ? 0 : root.kind === "fog" ? 0 : 6

    delegate: Item {
      id: cloud

      required property int index
      readonly property real w: 90 + root.rnd(index, 7) * 90
      readonly property real dark: root.gloomy ? 0.2 : 0.3

      y: root.rnd(index, 8) * (root.height * 0.55)
      width: w
      height: w * 0.4

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.6
        radius: height / 2
        color: root.night ? "#aab4c8" : "white"
        opacity: cloud.dark
      }
      Rectangle {
        x: parent.width * 0.18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.3
        width: parent.height * 0.8
        height: width
        radius: width / 2
        color: root.night ? "#aab4c8" : "white"
        opacity: cloud.dark
      }
      Rectangle {
        x: parent.width * 0.42
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.25
        width: parent.height * 1.05
        height: width
        radius: width / 2
        color: root.night ? "#aab4c8" : "white"
        opacity: cloud.dark
      }

      NumberAnimation on x {
        running: root.visible
        loops: Animation.Infinite
        from: root.width + 10 + root.rnd(cloud.index, 9) * 40
        to: -cloud.w - 10
        duration: 26000 + root.rnd(cloud.index, 10) * 26000
        // Start mid-sky rather than all off to the side.
        // (Each cloud begins at its own place along the way.)
      }
    }
  }

  // Fog: slow wide bands.
  Repeater {
    model: root.kind === "fog" ? 4 : 0

    delegate: Rectangle {
      required property int index

      y: root.height * (0.15 + index * 0.2)
      width: root.width * 1.2
      height: 34
      radius: 17
      color: "#cfd6df"
      opacity: 0.13

      SequentialAnimation on x {
        running: root.visible
        loops: Animation.Infinite
        NumberAnimation {
          from: -root.width * 0.2
          to: 0
          duration: 9000 + index * 2500
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          to: -root.width * 0.2
          duration: 9000 + index * 2500
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  // Rain and storms: slanted streaks falling.
  Repeater {
    model: root.kind === "rain" || root.kind === "storm" ? 34 : 0

    delegate: Rectangle {
      id: drop

      required property int index

      x: root.rnd(index, 11) * (root.width + 40)
      width: 1.5
      height: 12 + root.rnd(index, 12) * 10
      radius: 1
      rotation: 14
      color: "#bcd4f0"
      opacity: 0.18 + root.rnd(index, 13) * 0.25

      NumberAnimation on y {
        running: root.visible
        loops: Animation.Infinite
        from: -30
        to: root.height + 10
        duration: 650 + root.rnd(drop.index, 14) * 500
      }
    }
  }

  // Snow: slow flakes.
  Repeater {
    model: root.kind === "snow" ? 30 : 0

    delegate: Rectangle {
      id: flake

      required property int index
      readonly property real baseX: root.rnd(index, 15) * root.width

      width: 2 + root.rnd(index, 16) * 3
      height: width
      radius: width / 2
      color: "white"
      opacity: 0.35 + root.rnd(index, 17) * 0.4
      x: baseX

      NumberAnimation on y {
        running: root.visible
        loops: Animation.Infinite
        from: -10
        to: root.height + 6
        duration: 4200 + root.rnd(flake.index, 18) * 4000
      }

      SequentialAnimation on x {
        running: root.visible
        loops: Animation.Infinite
        NumberAnimation {
          to: flake.baseX + 14
          duration: 1800 + root.rnd(flake.index, 19) * 1200
          easing.type: Easing.InOutSine
        }
        NumberAnimation {
          to: flake.baseX - 14
          duration: 1800 + root.rnd(flake.index, 19) * 1200
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  // Lightning: a rare soft flash.
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: "#dfe8ff"
    opacity: 0
    visible: root.kind === "storm"

    SequentialAnimation on opacity {
      running: root.visible && root.kind === "storm"
      loops: Animation.Infinite
      PauseAnimation {
        duration: 3500
      }
      NumberAnimation {
        to: 0.28
        duration: 60
      }
      NumberAnimation {
        to: 0
        duration: 120
      }
      NumberAnimation {
        to: 0.18
        duration: 50
      }
      NumberAnimation {
        to: 0
        duration: 400
      }
      PauseAnimation {
        duration: 5000
      }
    }
  }

  // A dark wash from the bottom, so the hourly row and stats stay readable.
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    gradient: Gradient {
      GradientStop {
        position: 0.35
        color: "transparent"
      }
      GradientStop {
        position: 1
        color: Qt.rgba(0.02, 0.02, 0.03, 0.55)
      }
    }
  }
}
