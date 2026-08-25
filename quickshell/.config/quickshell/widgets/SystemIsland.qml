// SystemIsland.qml — volume, network, battery.
//
// Volume and network each open a control panel on left click.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

Row {
  id: root

  spacing: 13

  // Bar.qml uses this to make the panel focusable only while the Wi-Fi
  // password field is up — otherwise clicking the bar would steal focus from
  // whatever window you're in.
  readonly property bool wantsKeyboard: wifiPopup.wantsKeyboard

  // ------------------------------------------------------------------ volume
  Item {
    id: vol

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real level: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    readonly property string glyph: muted || level < 0.01 ? Icons.volMute : level < 0.34 ? Icons.volLow : level < 0.67 ? Icons.volMed : Icons.volHigh

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: volRow.implicitWidth
    implicitHeight: 18

    // Pipewire only publishes live property updates for nodes something is
    // actively tracking.
    PwObjectTracker {
      objects: vol.sink ? [vol.sink] : []
    }

    Row {
      id: volRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: vol.glyph
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: vol.muted ? Theme.fgDim : Theme.accent
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: vol.muted ? "--" : Math.round(vol.level * 100)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: event => {
        if (event.button === Qt.RightButton) {
          if (vol.audio)
            vol.audio.muted = !vol.audio.muted;
        } else {
          volumePopup.toggle();
        }
      }
    }

    WheelHandler {
      onWheel: event => {
        if (!vol.audio)
          return;
        const step = event.angleDelta.y > 0 ? 0.02 : -0.02;
        vol.audio.volume = Math.max(0, Math.min(1, vol.audio.volume + step));
      }
    }
  }

  // ----------------------------------------------------------------- network
  Item {
    id: net

    readonly property var wifiDevice: {
      const devices = Networking.devices ? Array.from(Networking.devices.values) : [];
      return devices.find(d => d.type === DeviceType.Wifi) ?? null;
    }

    readonly property var wired: {
      const devices = Networking.devices ? Array.from(Networking.devices.values) : [];
      return devices.find(d => d.type !== DeviceType.Wifi && d.connected) ?? null;
    }

    readonly property var activeNetwork: {
      if (!wifiDevice || !wifiDevice.networks)
        return null;
      return Array.from(wifiDevice.networks.values).find(n => n.connected) ?? null;
    }

    readonly property bool busy: wifiDevice ? wifiDevice.state === ConnectionState.Connecting : false

    readonly property string glyph: {
      if (wired)
        return Icons.ethernet;
      if (!Networking.wifiEnabled)
        return Icons.wifiOff;
      if (!activeNetwork)
        return Icons.noNetwork;
      // NetworkManager reports 0-100; be tolerant of a 0-1 backend.
      const raw = activeNetwork.signalStrength;
      const pct = raw <= 1.0 ? raw * 100 : raw;
      return Icons.wifiRamp[Math.max(0, Math.min(4, Math.ceil(pct / 25)))];
    }

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: netIcon.implicitWidth
    implicitHeight: 18

    Text {
      id: netIcon
      anchors.centerIn: parent
      text: net.glyph
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: net.wired || net.activeNetwork ? Theme.accent : net.busy ? Theme.warn : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: wifiPopup.toggle()
    }
  }

  // --------------------------------------------------------------- bluetooth
  Item {
    id: bt

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool poweredOn: adapter ? adapter.enabled : false
    readonly property int connectedCount: Bluetooth.devices ? Array.from(Bluetooth.devices.values).filter(d => d.connected).length : 0

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: btIcon.implicitWidth
    implicitHeight: 18

    Text {
      id: btIcon
      anchors.centerIn: parent
      text: !bt.poweredOn ? Icons.bluetoothOff : bt.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: bt.connectedCount > 0 ? Theme.accent : bt.poweredOn ? Theme.fg : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: bluetoothPopup.toggle()
    }
  }

  // Keep-awake indicator. Present only while the inhibitor is on, so it costs
  // no bar space in the normal case; clicking it turns it back off.
  Item {
    id: awake

    visible: IdleInhibit.enabled
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: awakeIcon.implicitWidth
    implicitHeight: 18

    Text {
      id: awakeIcon
      anchors.centerIn: parent
      text: Icons.coffee
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: awakeMouse.containsMouse ? Theme.crit : Theme.accent

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    MouseArea {
      id: awakeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: IdleInhibit.enabled = false
    }
  }

  // ----------------------------------------------------------------- battery
  Item {
    id: bat

    readonly property var device: UPower.displayDevice
    readonly property bool present: device ? device.isPresent : false

    // UPower reports 0-1 here, but be defensive: some backends report 0-100.
    readonly property int percent: {
      if (!device)
        return 0;
      const raw = device.percentage;
      return Math.round(raw <= 1.0 ? raw * 100 : raw);
    }

    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)

    readonly property string glyph: {
      if (!present)
        return Icons.batteryUnknown;
      if (charging)
        return Icons.batteryCharging;
      if (percent <= 5)
        return Icons.batteryAlert;
      return Icons.batteryRamp[Math.max(0, Math.min(10, Math.round(percent / 10)))];
    }

    readonly property color tint: charging ? Theme.good : percent <= 15 ? Theme.crit : percent <= 30 ? Theme.warn : Theme.accent

    visible: present
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: batRow.implicitWidth
    implicitHeight: 18

    Row {
      id: batRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bat.glyph
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: bat.tint

        // Pulse when critically low and not plugged in.
        SequentialAnimation on opacity {
          running: bat.percent <= 15 && !bat.charging
          loops: Animation.Infinite

          NumberAnimation {
            to: 0.35
            duration: 700
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            to: 1.0
            duration: 700
            easing.type: Easing.InOutSine
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bat.percent + "%"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }
    }
  }

  // ------------------------------------------------------------------ panels
  VolumePopup {
    id: volumePopup
    anchorItem: vol
  }

  WifiPopup {
    id: wifiPopup
    anchorItem: net
  }

  BluetoothPopup {
    id: bluetoothPopup
    anchorItem: bt
  }
}
