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
  component Glyph: Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize + 2
    color: Theme.fg
  }

  component Label: Text {
    font.family: Theme.fontFamily
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
      anchors.right: levelText.left
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      value: level.value
      onMoved: v => level.moved(v)
    }

    Label {
      id: levelText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 30
      horizontalAlignment: Text.AlignRight
      text: level.readout
      font.pixelSize: Theme.smallSize + 1
      color: Theme.fgDim
    }
  }

  // An app or tool in the grid.
  component Launcher: Rectangle {
    id: launcher

    property string glyph
    property string label
    property bool lit: false
    property int badge: 0
    signal activated(int button)

    width: (root.inner - 24) / 4
    height: 60
    radius: 14
    color: launchArea.containsMouse ? Theme.accentSoft : Theme.raised
    scale: launchArea.pressed ? 0.93 : 1
    transform: Translate {
      y: launchArea.containsMouse ? -2 : 0
      Behavior on y {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutBack
        }
      }
    }

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

    Column {
      anchors.centerIn: parent
      spacing: 6

      Glyph {
        anchors.horizontalCenter: parent.horizontalCenter
        text: launcher.glyph
        color: launcher.lit || launchArea.containsMouse ? Theme.accent : Theme.fg
      }
      Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: launcher.label
        font.pixelSize: Theme.smallSize
        color: launchArea.containsMouse ? Theme.accent : Theme.fgDim
      }
    }

    Rectangle {
      visible: launcher.badge > 0
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 6
      width: Math.max(16, badgeText.implicitWidth + 8)
      height: 16
      radius: 8
      color: Theme.accent

      Label {
        id: badgeText
        anchors.centerIn: parent
        text: launcher.badge > 99 ? "99+" : launcher.badge
        font.pixelSize: Theme.smallSize - 1
        font.bold: true
        color: Theme.base
      }
    }

    MouseArea {
      id: launchArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: event => launcher.activated(event.button)
    }
  }

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
          color: mediaBtnArea.containsMouse ? Theme.hover : main ? Theme.accentSoft : "transparent"
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
            color: mediaBtn.main ? Theme.accent : Theme.fg
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
      onMoved: v => root.audio.volume = v
      onGlyphClicked: button => {
        if (button === Qt.RightButton)
          root.audio.muted = !root.audio.muted;
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
  Column {
    id: appsSection
    spacing: 8
    transform: Translate {
      id: appsShift
    }

    Label {
      text: "APPS & TOOLS"
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Grid {
      columns: 4
      spacing: 8

      // Left click is the web app, right click the native chat — as the old
      // bar button did.
      Launcher {
        glyph: Icons.ai
        label: "AI"
        lit: AiChat.open || AiAssistant.shown
        onActivated: button => {
          root.close();
          if (button === Qt.RightButton) {
            Dashboard.close();
            AiChat.toggle();
            return;
          }
          AiChat.close();
          AiAssistant.toggle();
        }
      }

      Launcher {
        glyph: Icons.dashboard
        label: "Dashboard"
        lit: Dashboard.open
        onActivated: root.request("dashboard")
      }

      Launcher {
        glyph: Icons.sineWave
        label: "Tones"
        lit: Tones.active || Tones.timing
        onActivated: root.request("tones")
      }

      Launcher {
        glyph: Icons.windows
        label: "Windows"
        onActivated: root.request("windows")
      }

      Launcher {
        glyph: Icons.crop
        label: "Screenshot"
        onActivated: button => {
          root.close();
          shotDelay.whole = button === Qt.RightButton;
          shotDelay.restart();
        }
      }

      // Left click records the screen, right click picks a region.
      Launcher {
        glyph: Icons.record
        label: Recorder.recording ? "Stop" : "Record"
        lit: Recorder.recording
        onActivated: button => {
          root.close();
          recordDelay.region = button === Qt.RightButton;
          recordDelay.restart();
        }
      }

      Launcher {
        glyph: Sounds.enabled ? Icons.volHigh : Icons.volMute
        label: "Sounds"
        lit: Sounds.enabled
        onActivated: Sounds.toggle()
      }

      Launcher {
        glyph: Icons.clipboard
        label: "Clipboard"
        onActivated: root.request("clipboard")
      }

      Launcher {
        glyph: Icons.chip
        label: "System"
        onActivated: root.request("system")
      }

      Launcher {
        glyph: Icons.updates
        label: "Updates"
        badge: Updates.count
        lit: Updates.installing
        // Left click installs (progress shows in the island); right click
        // opens the list of what's pending.
        onActivated: button => {
          if (button === Qt.RightButton) {
            root.request("updates");
            return;
          }
          root.close();
          Updates.install();
        }
      }

      Launcher {
        visible: Drives.hasDrives
        glyph: Icons.usbDrive
        label: "Drives"
        onActivated: root.request("drives")
      }
    }
  }

  Timer {
    id: recordDelay
    property bool region: false
    interval: 320
    onTriggered: Recorder.toggle(region)
  }

  // Let this card get out of the frame before the capture starts.
  Timer {
    id: shotDelay
    property bool whole: false
    interval: 320
    onTriggered: whole ? Screenshot.fullScreen() : Screenshot.region()
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

    property string armed: ""

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

    Timer {
      id: disarm
      interval: 3500
      onTriggered: session.armed = ""
    }

    Connections {
      target: root
      function onOpenedChanged() {
        if (!root.opened)
          session.armed = "";
      }
    }

    function trigger(action) {
      if (action.confirm && session.armed !== action.id) {
        session.armed = action.id;
        disarm.restart();
        return;
      }
      session.armed = "";
      root.close();
      if (action.id === "screensaver")
        Screensaver.start();
      else
        Quickshell.execDetached(action.cmd);
    }

    Label {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - powerRow.width - 10
      font.pixelSize: Theme.smallSize + 1
      color: session.armed ? Theme.crit : Theme.fgDim
      text: {
        if (session.armed) {
          const a = session.actions.find(x => x.id === session.armed);
          return "Click again to " + a.label.toLowerCase();
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
            onClicked: session.trigger(pw.modelData)
          }
        }
      }
    }
  }
}
