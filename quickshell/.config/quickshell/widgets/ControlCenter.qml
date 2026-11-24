// ControlCenter.qml — everything that used to be spread across the bar.
//
// Grows out of the status pill on the right (MorphPanel.qml). Top to bottom:
//   quick toggles · volume / brightness / warmth · wallpaper · apps & tools ·
//   battery and the session actions.
//
// Anything with a richer panel of its own (Wi-Fi networks, Bluetooth devices,
// audio outputs, clipboard, updates…) is reached through `panelRequested`;
// StatusCluster.qml owns those panels and opens them in this one's place.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

MorphPanel {
  id: root

  cardWidth: 372
  contentSpacing: 14


  signal panelRequested(string name)

  readonly property int inner: cardWidth - 28

  // StatusCluster.qml decides how: slide across to a detail panel, or fold
  // away for the wallpaper picker.
  function request(name) {
    root.panelRequested(name);
  }

  // ---------------------------------------------------------------- sources
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  readonly property var wifiDevice: {
    const devices = Networking.devices ? Array.from(Networking.devices.values) : [];
    return devices.find(d => d.type === DeviceType.Wifi) ?? null;
  }
  readonly property var activeNetwork: {
    if (!wifiDevice || !wifiDevice.networks)
      return null;
    return Array.from(wifiDevice.networks.values).find(n => n.connected) ?? null;
  }

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var btDevices: Bluetooth.devices ? Array.from(Bluetooth.devices.values).filter(d => d.connected) : []
  readonly property int btConnected: btDevices.length

  // "Headphones · 80%" for the first connected device, battery if it reports one.
  readonly property string btSummary: {
    if (btDevices.length === 0)
      return "";
    const d = btDevices[0];
    const name = d.name || d.deviceName || "Device";
    const extra = btDevices.length > 1 ? " +" + (btDevices.length - 1) : "";
    return d.batteryAvailable ? name + " · " + Math.round(d.battery * 100) + "%" + extra : name + extra;
  }

  // Signal strength, NetworkManager's 0–100 (or 0–1 on some backends).
  readonly property int wifiSignal: {
    if (!activeNetwork)
      return 0;
    const raw = activeNetwork.signalStrength;
    return Math.round(raw <= 1.0 ? raw * 100 : raw);
  }

  readonly property var battery: UPower.displayDevice

  function hours(seconds) {
    if (!seconds || seconds <= 0)
      return "";
    const h = Math.floor(seconds / 3600);
    const m = Math.round((seconds % 3600) / 60);
    return h > 0 ? h + " h " + m + " min" : m + " min";
  }

  // --------------------------------------------------------------- entrance
  // Each section rises into place a beat after the one above it, while the
  // card itself is still springing open.
  component Rise: SequentialAnimation {
    id: rise

    property Item item
    property Translate shift
    property int delay: 0

    PropertyAction {
      target: rise.item
      property: "opacity"
      value: 0
    }
    PropertyAction {
      target: rise.shift
      property: "y"
      value: 14
    }
    PauseAnimation {
      duration: rise.delay
    }
    ParallelAnimation {
      NumberAnimation {
        target: rise.item
        property: "opacity"
        to: 1
        duration: 320
        easing.type: Easing.OutQuad
      }
      NumberAnimation {
        target: rise.shift
        property: "y"
        to: 0
        duration: 560
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 1.4, 0.5, 1, 1, 1]
      }
    }
  }

  readonly property var rises: [riseTiles, riseMedia, riseLevels, riseWall, riseApps, riseSession]

  Connections {
    target: root
    function onOpenedChanged() {
      if (root.opened) {
        for (const r of root.rises)
          r.restart();
      }
    }
  }

  Rise {
    id: riseTiles
    item: tilesSection
    shift: tilesShift
    delay: 40
  }
  Rise {
    id: riseMedia
    item: mediaSection
    shift: mediaShift
    delay: 62
  }
  Rise {
    id: riseLevels
    item: levelsSection
    shift: levelsShift
    delay: 85
  }
  Rise {
    id: riseWall
    item: wallSection
    shift: wallShift
    delay: 130
  }
  Rise {
    id: riseApps
    item: appsSection
    shift: appsShift
    delay: 175
  }
  Rise {
    id: riseSession
    item: session
    shift: sessionShift
    delay: 220
  }

  // ------------------------------------------------------------- components
  component Glyph: GlyphSwap {
    font.pixelSize: Theme.iconSize + 2
  }

  component Label: Text {
    font.family: Theme.textFamily
    font.features: Theme.tabular
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    elide: Text.ElideRight
  }

  // A quick toggle. The chevron side opens the full panel where there is one.
  component Tile: Rectangle {
    id: tile

    property bool on: false
    property string glyph
    property string label
    property string sub
    property string detail: ""
    signal toggled

    width: (root.inner - 8) / 2
    height: 54
    radius: 16
    color: on ? (tileArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : tileArea.containsMouse ? Theme.hover : Theme.raised
    scale: tileArea.pressed ? 0.96 : 1

    Behavior on color {
      ColorAnimation {
        duration: 220
      }
    }
    Behavior on scale {
      SpringAnimation {
        spring: 6
        damping: 0.3
        epsilon: 0.002
      }
    }

    MouseArea {
      id: tileArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.toggled()
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 11

      Glyph {
        anchors.verticalCenter: parent.verticalCenter
        text: tile.glyph
        filled: tile.on
        color: tile.on ? Theme.base : Theme.fg
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
          width: tile.width - 14 - 11 - 20 - (tile.detail ? 28 : 12)
          text: tile.label
          font.bold: true
          color: tile.on ? Theme.base : Theme.fg
        }
        Label {
          width: tile.width - 14 - 11 - 20 - (tile.detail ? 28 : 12)
          text: tile.sub
          font.pixelSize: Theme.smallSize
          color: tile.on ? Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.7) : Theme.fgDim
        }
      }
    }

    Rectangle {
      visible: tile.detail.length > 0
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: 24
      height: 36
      radius: 10
      color: detailArea.containsMouse ? Qt.rgba(0, 0, 0, 0.12) : "transparent"

      Glyph {
        anchors.centerIn: parent
        text: Icons.chevronRight
        font.pixelSize: Theme.iconSize
        color: tile.on ? Theme.base : Theme.fgDim
      }

      MouseArea {
        id: detailArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.request(tile.detail)
      }
    }
  }

  // A slider row; the glyph opens the matching panel (or mutes, for volume).
  component Level: Item {
    id: level

    property string glyph
    property real value
    property string readout
    signal moved(real v)
    signal glyphClicked(int button)

    width: root.inner
    height: 26

    Glyph {
      id: levelGlyph
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 22
      horizontalAlignment: Text.AlignHCenter
      text: level.glyph
      color: level.enabled ? (glyphArea.containsMouse ? Theme.accent : Theme.fg) : Theme.fgDim

      MouseArea {
        id: glyphArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => level.glyphClicked(event.button)
      }
    }

    Slider {
      anchors.left: levelGlyph.right
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      pill: true
      readout: level.readout
      value: level.value
      onMoved: v => level.moved(v)
    }
  }

  // An app or tool in the grid.
  // ---------------------------------------------------------------- toggles
  Grid {
    id: tilesSection
    columns: 2
    spacing: 8
    transform: Translate {
      id: tilesShift
    }

    Tile {
      on: Networking.wifiEnabled
      glyph: !Networking.wifiEnabled ? Icons.wifiOff : root.activeNetwork ? Icons.wifiRamp[4] : Icons.noNetwork
      label: "Wi-Fi"
      sub: !Networking.wifiEnabled ? "Off" : root.activeNetwork ? root.activeNetwork.name + " · " + root.wifiSignal + "%" : "Not connected"
      detail: "wifi"
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    Tile {
      on: root.adapter ? root.adapter.enabled : false
      glyph: !on ? Icons.bluetoothOff : root.btConnected > 0 ? Icons.bluetoothConnected : Icons.bluetooth
      label: "Bluetooth"
      sub: !on ? "Off" : root.btConnected > 0 ? root.btSummary : "On"
      detail: "bluetooth"
      onToggled: {
        if (root.adapter)
          root.adapter.enabled = !root.adapter.enabled;
      }
    }

    Tile {
      on: IdleInhibit.enabled
      glyph: IdleInhibit.enabled ? Icons.coffee : Icons.coffeeOff
      label: "Keep awake"
      sub: IdleInhibit.enabled ? "Idle paused" : "Off"
      onToggled: IdleInhibit.toggle()
    }

    Tile {
      on: Notifications.doNotDisturb
      glyph: Notifications.doNotDisturb ? Icons.bellOff : Icons.bell
      label: "Do not disturb"
      sub: Notifications.doNotDisturb ? "Silenced" : Notifications.count > 0 ? Notifications.count + " waiting" : "Off"
      detail: "notifications"
      onToggled: Notifications.doNotDisturb = !Notifications.doNotDisturb
    }

    // Warmth on or off; the slider below sets how warm.
    Tile {
      on: Backlight.temperatureAvailable && Backlight.temperature < Backlight.neutralTemperature
      glyph: Icons.warmth
      label: "Night light"
      sub: !Backlight.temperatureAvailable ? "Needs hyprsunset" : on ? Backlight.temperature + "K" : "Off"
      onToggled: {
        if (Backlight.temperatureAvailable)
          Backlight.setTemperature(on ? Backlight.neutralTemperature : 4500);
      }
    }

    // Cycles the island clock's face: LED, amber, plain.
    Tile {
      on: ClockStyle.skin !== "plain"
      glyph: Icons.timer
      label: "Clock face"
      sub: ClockStyle.name
      onToggled: ClockStyle.next()
    }

    Tile {
      on: !Theme.isLight
      glyph: Theme.isLight ? Icons.sun : Icons.moon
      label: "Dark mode"
      sub: Theme.isLight ? "Light" : "From wallpaper"
      onToggled: Theme.toggleMode()
    }
  }

  // ------------------------------------------------------------ now playing
  // Only while a player is around: cover, title, and the three buttons, so
  // the music is reachable without going to the island.
  Rectangle {
    id: mediaSection
    transform: Translate {
      id: mediaShift
    }
    visible: Media.hasPlayer
    width: root.inner
    height: 54
    radius: 14
    color: Theme.raised

    // The song's own colour (from its cover), fading in and out as songs come
    // and go. Without one, the wallpaper's accent as before.
    property color cover: Media.hasCoverTint ? Media.coverTint : Theme.accent
    // The same colour pushed light (or dark, on a light theme) so it reads on
    // the card.
    readonly property color coverInk: Qt.hsla(Math.max(0, cover.hslHue), Math.min(1, cover.hslSaturation), Theme.isLight ? Math.min(0.38, cover.hslLightness) : Math.max(0.68, cover.hslLightness), 1)

    Behavior on cover {
      ColorAnimation {
        duration: Theme.motionAmbient
      }
    }

    // A wash of that colour from the left.
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      opacity: Media.hasCoverTint ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.motionAmbient
        }
      }

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
          position: 0
          color: Qt.rgba(mediaSection.cover.r, mediaSection.cover.g, mediaSection.cover.b, 0.34)
        }
        GradientStop {
          position: 0.8
          color: Qt.rgba(mediaSection.cover.r, mediaSection.cover.g, mediaSection.cover.b, 0)
        }
      }
    }

    ClippingRectangle {
      id: mediaArt
      anchors.left: parent.left
      anchors.leftMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      width: 36
      height: 36
      radius: 8
      color: Theme.accentSoft

      Image {
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 108
        sourceSize.height: 108
        mipmap: true
      }
    }

    Column {
      anchors.left: mediaArt.right
      anchors.leftMargin: 11
      anchors.right: mediaControls.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      Label {
        width: parent.width
        text: Media.title || "Nothing playing"
        font.bold: true
      }
      Label {
        width: parent.width
        text: Media.artist
        font.pixelSize: Theme.smallSize + 1
        color: Theme.fgDim
      }
    }

    Row {
      id: mediaControls
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

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
          id: mediaBtn

          required property var modelData
          readonly property bool main: modelData.act === "toggle"

          width: main ? 34 : 28
          height: width
          radius: width / 2
          color: mediaBtnArea.containsMouse ? Theme.hover : main ? Qt.rgba(mediaSection.cover.r, mediaSection.cover.g, mediaSection.cover.b, 0.24) : "transparent"
          scale: mediaBtnArea.pressed ? 0.86 : 1

          Behavior on scale {
            NumberAnimation {
              duration: 260
              easing.type: Easing.BezierSpline
              easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
            }
          }

          Glyph {
            anchors.centerIn: parent
            text: mediaBtn.modelData.glyph
            font.pixelSize: mediaBtn.main ? Theme.iconSize + 2 : Theme.iconSize
            color: mediaBtn.main ? mediaSection.coverInk : Theme.fg
          }

          MouseArea {
            id: mediaBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const p = Media.active;
              if (!p)
                return;
              if (mediaBtn.modelData.act === "prev" && p.canGoPrevious)
                p.previous();
              else if (mediaBtn.modelData.act === "next" && p.canGoNext)
                p.next();
              else if (mediaBtn.modelData.act === "toggle" && p.canTogglePlaying)
                p.togglePlaying();
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------------------- levels
  Column {
    id: levelsSection
    spacing: 8
    transform: Translate {
      id: levelsShift
    }

    Level {
      glyph: !root.audio || root.audio.muted ? Icons.volMute : root.audio.volume < 0.34 ? Icons.volLow : root.audio.volume < 0.67 ? Icons.volMed : Icons.volHigh
      value: root.audio ? root.audio.volume : 0
      readout: !root.audio ? "--" : root.audio.muted ? "off" : Math.round(root.audio.volume * 100)
      enabled: root.audio !== null
      onMoved: v => Volume.set(root.sink, v)
      onGlyphClicked: button => {
        if (button === Qt.RightButton)
          Volume.toggleMute(root.sink);
        else
          root.request("volume");
      }
    }

    Level {
      glyph: Icons.brightness
      value: Backlight.brightness
      readout: Backlight.brightnessAvailable ? Math.round(Backlight.brightness * 100) : "--"
      enabled: Backlight.brightnessAvailable
      onMoved: v => Backlight.setBrightness(v)
      onGlyphClicked: root.request("brightness")
    }

    Level {
      glyph: Icons.warmth
      value: (Backlight.neutralTemperature - Backlight.temperature) / (Backlight.neutralTemperature - Backlight.warmestTemperature)
      readout: Backlight.temperatureAvailable ? Math.round(value * 100) : "--"
      enabled: Backlight.temperatureAvailable
      onMoved: v => Backlight.setTemperature(Math.round(Backlight.neutralTemperature - v * (Backlight.neutralTemperature - Backlight.warmestTemperature)))
      onGlyphClicked: root.request("brightness")
    }
  }

  // -------------------------------------------------------------- wallpaper
  // The current wallpaper (click for the full picker) and the next few in the
  // folder, applied straight from here with the middle-out reveal.
  readonly property var upNext: {
    const n = Wallpaper.count;
    if (n < 2)
      return [];
    const start = Math.max(0, Wallpaper.currentIndex);
    const out = [];
    for (let i = 1; i <= Math.min(5, n - 1); i++)
      out.push(Wallpaper.files[(start + i) % n]);
    return out;
  }

  Column {
    id: wallSection
    transform: Translate {
      id: wallShift
    }
    width: root.inner
    spacing: 8

  ClippingRectangle {
    width: root.inner
    height: 64
    radius: 14
    color: Theme.raised

    Image {
      id: wallThumb
      anchors.fill: parent
      source: Wallpaper.current ? "file://" + Wallpaper.thumbFor(Wallpaper.current) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 720
      scale: wallArea.containsMouse ? 1.06 : 1

      Behavior on scale {
        NumberAnimation {
          duration: 900
          easing.type: Easing.OutQuint
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop {
          position: 0.3
          color: Qt.rgba(0, 0, 0, 0)
        }
        GradientStop {
          position: 1
          color: Qt.rgba(0, 0, 0, 0.65)
        }
      }
    }

    Row {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: 11
      spacing: 8

      Glyph {
        text: Icons.wallpaper
        color: "white"
        font.pixelSize: Theme.iconSize
      }
      Label {
        text: "Change wallpaper"
        font.bold: true
        color: "white"
      }
    }

    MouseArea {
      id: wallArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.request("wallpaper")
    }

    // Parallax on or off: the wallpaper sliding with the workspaces.
    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 9
      width: parallaxRow.implicitWidth + 18
      height: 24
      radius: 12
      color: Wallpaper.parallax ? Theme.accent : parallaxArea.containsMouse ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.45)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, Wallpaper.parallax ? 0 : 0.25)

      Behavior on color {
        ColorAnimation {
          duration: 180
        }
      }

      Row {
        id: parallaxRow
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 6
          height: 6
          radius: 3
          color: Wallpaper.parallax ? Theme.base : "white"
          opacity: Wallpaper.parallax ? 1 : 0.6
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: "Parallax"
          font.pixelSize: Theme.smallSize
          font.bold: true
          color: Wallpaper.parallax ? Theme.base : "white"
        }
      }

      MouseArea {
        id: parallaxArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Wallpaper.setParallax(!Wallpaper.parallax)
      }
    }
  }

  Row {
    spacing: 6

    Repeater {
      model: root.upNext

      delegate: ClippingRectangle {
        id: nextWall

        required property string modelData
        required property int index

        width: (root.inner - 6 * 4) / 5
        height: 40
        radius: 9
        color: Theme.raised
        border.width: nextArea.containsMouse ? 2 : 0
        border.color: Theme.accent
        scale: nextArea.pressed ? 0.92 : 1
        transform: Translate {
          y: nextArea.containsMouse ? -2 : 0
          Behavior on y {
            NumberAnimation {
              duration: 200
              easing.type: Easing.OutCubic
            }
          }
        }

        Behavior on scale {
          NumberAnimation {
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
          }
        }

        Image {
          anchors.fill: parent
          source: root.opened ? "file://" + Wallpaper.thumbFor(nextWall.modelData) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 180
          opacity: status === Image.Ready ? 1 : 0

          Behavior on opacity {
            NumberAnimation {
              duration: 200
            }
          }
        }

        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.close();
            Wallpaper.apply(nextWall.modelData);
          }
        }
      }
    }
  }
  }

  // ---------------------------------------------------------- apps & tools
  // One row; the grid of launchers lives in its own panel (ToolsPopup.qml) so
  // this card stays short enough for the screen.
  Rectangle {
    id: appsSection
    width: root.inner
    height: 46
    radius: 14
    color: appsArea.containsMouse ? Theme.accentSoft : "transparent"
    border.width: 1
    border.color: Theme.border
    transform: Translate {
      id: appsShift
    }

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    Glyph {
      id: appsGlyph
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.dashboard
      color: appsArea.containsMouse ? Theme.accent : Theme.fg
    }

    Label {
      anchors.left: appsGlyph.right
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: "Apps & tools"
      font.bold: true
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: Updates.count > 0
        text: Updates.count + " updates"
        color: Theme.fgDim
      }
      Label {
        font.family: Theme.iconFamily
        font.pixelSize: Theme.iconSize + 2
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.chevronRight
        color: Theme.fgDim
      }
    }

    MouseArea {
      id: appsArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.request("tools")
    }
  }

  // ---------------------------------------------------------------- session
  Rectangle {
    width: root.inner
    height: 1
    color: Theme.border
  }

  Item {
    width: root.inner
    height: 34

    // The button being held down, and the one the pointer is over; the buttons
    // that end your session fire only after being held (see `holdMs`).
    property string armed: ""
    property string hovered: ""
    readonly property int holdMs: 700

    readonly property var actions: [
      {
        id: "screensaver",
        label: "Screensaver",
        glyph: Icons.screensaver,
        confirm: false
      },
      {
        id: "lock",
        label: "Lock",
        glyph: Icons.lock,
        confirm: false,
        cmd: ["hyprlock"]
      },
      {
        id: "suspend",
        label: "Sleep",
        glyph: Icons.sleep,
        confirm: false,
        cmd: ["systemctl", "suspend"]
      },
      {
        id: "logout",
        label: "Log out",
        glyph: Icons.logout,
        confirm: true,
        cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || hyprctl dispatch exit"]
      },
      {
        id: "reboot",
        label: "Restart",
        glyph: Icons.restart,
        confirm: true,
        cmd: ["systemctl", "reboot"]
      },
      {
        id: "poweroff",
        label: "Shut down",
        glyph: Icons.power,
        confirm: true,
        cmd: ["systemctl", "poweroff"]
      }
    ]

    id: session
    transform: Translate {
      id: sessionShift
    }

    Connections {
      target: root
      function onOpenedChanged() {
        if (!root.opened) {
          session.armed = "";
          session.hovered = "";
        }
      }
    }

    function trigger(action) {
      session.armed = "";
      root.close();
      if (action.id === "screensaver")
        Screensaver.start();
      else if (action.confirm)
        Moments.runSession(action.label, action.cmd);
      else
        Quickshell.execDetached(action.cmd);
    }

    Label {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - powerRow.width - 10
      font.pixelSize: Theme.smallSize + 1
      color: session.armed || session.hovered ? Theme.crit : Theme.fgDim
      text: {
        if (session.armed || session.hovered) {
          const a = session.actions.find(x => x.id === (session.armed || session.hovered));
          return "Hold to " + a.label.toLowerCase();
        }
        if (!root.battery || !root.battery.isPresent)
          return Time.longDate;
        const pct = Moments.batteryPercent + "%";
        if (Moments.charging) {
          const full = root.hours(root.battery.timeToFull);
          return "Charging · " + pct + (full ? " · full in " + full : "");
        }
        const left = root.hours(root.battery.timeToEmpty);
        return "Battery " + pct + (left ? " · " + left + " left" : "");
      }
    }

    Row {
      id: powerRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 5

      Repeater {
        model: session.actions

        delegate: Rectangle {
          id: pw

          required property var modelData
          readonly property bool isArmed: session.armed === modelData.id
          // 0..1 while the button is held; drains back when let go early.
          property real held: 0

          width: 32
          height: 32
          radius: 11
          color: isArmed ? Qt.rgba(Theme.crit.r, Theme.crit.g, Theme.crit.b, 0.25) : pwArea.containsMouse ? Theme.hover : Theme.raised
          scale: pwArea.pressed ? 0.9 : 1

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }
          Behavior on scale {
            SpringAnimation {
              spring: 6
              damping: 0.3
              epsilon: 0.002
            }
          }

          // The ring that closes as you hold.
          Shape {
            anchors.fill: parent
            visible: pw.held > 0.001
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              strokeWidth: 2.4
              strokeColor: Theme.crit
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap

              PathAngleArc {
                centerX: pw.width / 2
                centerY: pw.height / 2
                radiusX: pw.width / 2 - 2
                radiusY: pw.height / 2 - 2
                startAngle: -90
                sweepAngle: 360 * pw.held
              }
            }
          }

          NumberAnimation {
            id: holdFill
            target: pw
            property: "held"
            // `from` and `duration` are set when the press starts (a binding
            // on the value being animated would change them mid-run).
            to: 1
            duration: session.holdMs
            onFinished: {
              if (pw.held >= 1) {
                pw.held = 0;
                session.trigger(pw.modelData);
              }
            }
          }

          NumberAnimation {
            id: holdDrain
            target: pw
            property: "held"
            to: 0
            duration: 260
            easing.type: Easing.OutQuad
          }

          Glyph {
            anchors.centerIn: parent
            text: pw.modelData.glyph
            font.pixelSize: Theme.iconSize
            color: pw.isArmed || (pwArea.containsMouse && pw.modelData.confirm) ? Theme.crit : pwArea.containsMouse ? Theme.accent : Theme.fgDim
          }

          MouseArea {
            id: pwArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
              if (containsMouse && pw.modelData.confirm)
                session.hovered = pw.modelData.id;
              else if (session.hovered === pw.modelData.id)
                session.hovered = "";
              // Sliding off while holding cancels it.
              if (!containsMouse && pw.isArmed)
                pwArea.release();
            }
            function release() {
              holdFill.stop();
              if (session.armed === pw.modelData.id)
                session.armed = "";
              holdDrain.restart();
            }
            onPressed: {
              if (!pw.modelData.confirm)
                return;
              session.armed = pw.modelData.id;
              holdDrain.stop();
              holdFill.stop();
              holdFill.from = pw.held;
              holdFill.duration = session.holdMs * (1 - pw.held);
              holdFill.start();
            }
            onReleased: if (pw.modelData.confirm)
              pwArea.release()
            onCanceled: if (pw.modelData.confirm)
              pwArea.release()
            onClicked: {
              if (!pw.modelData.confirm)
                session.trigger(pw.modelData);
            }
          }
        }
      }
    }
  }
}
