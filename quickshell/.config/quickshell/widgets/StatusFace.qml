// StatusFace.qml — the status pill's icons: network, Bluetooth, volume,
// battery. Drawn twice: on the bar, and as the header of the control center
// that grows out of it (ControlCenter.qml), so the two line up exactly.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

Item {
  id: root

  // Brightened while hovered or while the control center is open.
  property bool lit: false

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  // --------------------------------------------------------------- sources
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

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
  readonly property string netGlyph: {
    if (wired)
      return Icons.ethernet;
    if (!Networking.wifiEnabled)
      return Icons.wifiOff;
    if (!activeNetwork)
      return Icons.noNetwork;
    const raw = activeNetwork.signalStrength;
    const pct = raw <= 1.0 ? raw * 100 : raw;
    return Icons.wifiRamp[Math.max(0, Math.min(4, Math.ceil(pct / 25)))];
  }

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool btOn: adapter ? adapter.enabled : false
  readonly property int btConnected: Bluetooth.devices ? Array.from(Bluetooth.devices.values).filter(d => d.connected).length : 0

  readonly property var battery: UPower.displayDevice
  readonly property bool batteryPresent: battery ? battery.isPresent : false
  readonly property int percent: Moments.batteryPercent ?? 0
  readonly property string batGlyph: {
    if (!batteryPresent)
      return Icons.batteryUnknown;
    if (Moments.charging)
      return Icons.batteryCharging;
    if (percent <= 5)
      return Icons.batteryAlert;
    return Icons.batteryRamp[Math.max(0, Math.min(10, Math.round(percent / 10)))];
  }
  readonly property color batTint: Moments.charging ? Theme.good : percent <= 15 ? Theme.crit : percent <= 30 ? Theme.warn : Theme.fg

  // ------------------------------------------------------------------- face
  component Glyph: Text {
    anchors.verticalCenter: parent.verticalCenter
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: root.lit ? Theme.fg : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 11

    Pulse {
      anchors.verticalCenter: parent.verticalCenter
    }

    Glyph {
      text: root.netGlyph
      color: root.wired || root.activeNetwork ? Theme.accent : Theme.fgDim
    }

    Glyph {
      text: !root.btOn ? Icons.bluetoothOff : root.btConnected > 0 ? Icons.bluetoothConnected : Icons.bluetooth
      color: root.btConnected > 0 ? Theme.accent : root.btOn ? Theme.fg : Theme.fgDim
    }

    Glyph {
      text: !root.audio || root.audio.muted ? Icons.volMute : root.audio.volume < 0.34 ? Icons.volLow : root.audio.volume < 0.67 ? Icons.volMed : Icons.volHigh
      color: root.audio && !root.audio.muted ? Theme.fg : Theme.fgDim
    }

    Row {
      visible: root.batteryPresent
      anchors.verticalCenter: parent.verticalCenter
      spacing: 5

      Glyph {
        text: root.batGlyph
        color: root.batTint

        SequentialAnimation on opacity {
          running: root.percent <= 15 && !Moments.charging && root.batteryPresent
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
        text: root.percent + "%"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }
    }
  }

}
