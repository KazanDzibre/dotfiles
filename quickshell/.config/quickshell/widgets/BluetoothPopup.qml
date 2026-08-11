// BluetoothPopup.qml — connect, pair and forget Bluetooth devices.
//
// Discovery is only switched on while the panel is open. Scanning is expensive
// and keeps the radio busy, and a bar has no business doing it in the
// background.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs

Popup {
  id: root

  cardWidth: 320
  align: "right"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool poweredOn: adapter ? adapter.enabled : false
  readonly property bool scanning: adapter ? adapter.discovering : false

  // Connected first, then remembered, then whatever the scan turns up.
  // Unnamed devices are noise — a bare MAC address tells you nothing.
  readonly property var devices: {
    if (!Bluetooth.devices)
      return [];
    return Array.from(Bluetooth.devices.values).filter(d => (d.deviceName ?? d.name ?? "").length > 0).sort((a, b) => {
      if (a.connected !== b.connected)
        return a.connected ? -1 : 1;
      const ap = a.paired || a.bonded;
      const bp = b.paired || b.bonded;
      if (ap !== bp)
        return ap ? -1 : 1;
      return root.label(a).localeCompare(root.label(b));
    });
  }

  // Gated on `when` rather than driven by `value`, so that at startup — panel
  // closed, nothing scanning — no write happens at all. Binding restores the
  // previous value when the condition drops, which stops the scan on close.
  Binding {
    target: root.adapter
    property: "discovering"
    value: true
    when: root.adapter !== null && root.visible && root.poweredOn
  }

  function label(device) {
    return device.deviceName || device.name || device.address;
  }

  function busy(device) {
    return device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
  }

  function subtitle(device) {
    if (device.pairing)
      return "Pairing…";
    if (device.state === BluetoothDeviceState.Connecting)
      return "Connecting…";
    if (device.state === BluetoothDeviceState.Disconnecting)
      return "Disconnecting…";
    if (device.connected) {
      if (device.batteryAvailable) {
        const raw = device.battery;
        const pct = Math.round(raw <= 1.0 ? raw * 100 : raw);
        return "Connected  ·  " + pct + "%";
      }
      return "Connected";
    }
    if (device.paired || device.bonded)
      return "Paired";
    return "Available";
  }

  // One click does the obvious next thing for whatever state the device is in.
  function activate(device) {
    if (root.busy(device))
      return;
    if (device.connected) {
      device.disconnect();
      return;
    }
    if (device.paired || device.bonded) {
      device.connect();
      return;
    }
    device.pair();
  }

  // -------------------------------------------------------------- header row
  Item {
    width: parent.width
    height: 24

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "BLUETOOTH"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.scanning
        text: "scanning…"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim

        SequentialAnimation on opacity {
          running: root.scanning
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

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 20
        radius: 10
        color: root.poweredOn ? Theme.accent : Theme.raised

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Rectangle {
          x: root.poweredOn ? parent.width - width - 3 : 3
          anchors.verticalCenter: parent.verticalCenter
          width: 14
          height: 14
          radius: 7
          color: root.poweredOn ? Theme.base : Theme.fgDim

          Behavior on x {
            NumberAnimation {
              duration: Theme.animSlow
              easing.type: Easing.OutBack
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.adapter)
              root.adapter.enabled = !root.adapter.enabled;
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- adapter states
  Text {
    width: parent.width
    visible: root.adapter === null
    text: "No Bluetooth adapter found."
    wrapMode: Text.WordWrap
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  Text {
    width: parent.width
    visible: root.adapter !== null && !root.poweredOn
    text: "Bluetooth is off."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  // ------------------------------------------------------------ device list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 250)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: root.poweredOn && root.devices.length > 0

    Column {
      id: listColumn
      width: parent.width
      spacing: 2

      Repeater {
        model: root.devices

        delegate: Rectangle {
          id: deviceRow

          required property var modelData

          readonly property bool isBusy: root.busy(modelData)
          readonly property bool known: modelData.paired || modelData.bonded
          readonly property string iconUrl: Icons.themeIcon(modelData.icon)

          width: listColumn.width
          height: 36
          radius: 9
          color: modelData.connected ? Theme.accentSoft : rowHover.containsMouse ? Theme.hover : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }

          IconImage {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceRow.iconUrl !== ""
            source: deviceRow.iconUrl
            implicitSize: 18
            asynchronous: true
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceRow.iconUrl === ""
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: Icons.forBluetoothDevice(deviceRow.modelData.icon)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: deviceRow.modelData.connected ? Theme.accent : Theme.fg
          }

          Column {
            anchors.left: parent.left
            anchors.leftMargin: 35
            anchors.right: forgetButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              width: parent.width
              text: root.label(deviceRow.modelData)
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: deviceRow.modelData.connected ? Theme.accent : Theme.fg
            }

            Text {
              width: parent.width
              text: root.subtitle(deviceRow.modelData)
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 1
              color: Theme.fgDim
            }
          }

          // Spinner while BlueZ works.
          Text {
            anchors.right: forgetButton.left
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceRow.isBusy
            text: Icons.spinner
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Theme.accent

            RotationAnimation on rotation {
              running: deviceRow.isBusy
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 900
            }
          }

          Rectangle {
            id: forgetButton

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            visible: deviceRow.known
            opacity: rowHover.containsMouse || forgetHover.containsMouse ? 1 : 0
            color: forgetHover.containsMouse ? Theme.crit : "transparent"

            Behavior on opacity {
              NumberAnimation {
                duration: Theme.animFast
              }
            }

            Text {
              anchors.centerIn: parent
              text: Icons.forget
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize + 3
              color: forgetHover.containsMouse ? Theme.base : Theme.fgDim
            }

            MouseArea {
              id: forgetHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: deviceRow.modelData.forget()
            }
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            anchors.rightMargin: deviceRow.known ? 30 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(deviceRow.modelData)
          }
        }
      }
    }
  }

  Text {
    width: parent.width
    visible: root.poweredOn && root.devices.length === 0
    text: root.scanning ? "Looking for devices…" : "No devices found."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }
}
