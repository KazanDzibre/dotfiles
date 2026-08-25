// WifiPopup.qml — network picker with password entry.
//
// Scanning is only switched on while the popup is open, so the radio isn't
// burning power the rest of the time.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs

Popup {
  id: root

  cardWidth: 320
  align: "right"

  readonly property var wifiDevice: {
    const devices = Networking.devices ? Array.from(Networking.devices.values) : [];
    return devices.find(d => d.type === DeviceType.Wifi) ?? null;
  }

  // The network we're currently asking for a password for, if any.
  property var pendingNetwork: null
  property string password: ""
  property string errorText: ""

  // Bar.qml reads this to decide when the panel should accept keystrokes.
  readonly property bool wantsKeyboard: opened && pendingNetwork !== null

  // Access points are per-BSSID, so the same SSID can appear several times.
  // Keep the strongest of each, connected first, then by signal.
  readonly property var networks: {
    if (!wifiDevice || !wifiDevice.networks)
      return [];
    const strongest = {};
    for (const n of Array.from(wifiDevice.networks.values)) {
      if (!n.name)
        continue;
      const existing = strongest[n.name];
      if (!existing || n.signalStrength > existing.signalStrength)
        strongest[n.name] = n;
    }
    return Object.values(strongest).sort((a, b) => {
      if (a.connected !== b.connected)
        return a.connected ? -1 : 1;
      return b.signalStrength - a.signalStrength;
    });
  }

  Binding {
    target: root.wifiDevice
    property: "scannerEnabled"
    value: root.opened
    when: root.wifiDevice !== null
  }

  onOpenedChanged: {
    if (!opened) {
      root.pendingNetwork = null;
      root.password = "";
      root.errorText = "";
    }
  }

  function needsPassword(network) {
    return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
  }

  // EAP wants a certificate and identity, which is more than one text field can
  // honestly collect — send those to nmtui rather than pretend.
  function isEnterprise(network) {
    const s = network.security;
    return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap || s === WifiSecurityType.Wpa3SuiteB192 || s === WifiSecurityType.DynamicWep || s === WifiSecurityType.Leap;
  }

  function signalGlyph(strength) {
    const pct = strength <= 1.0 ? strength * 100 : strength;
    return Icons.wifiRamp[Math.max(0, Math.min(4, Math.ceil(pct / 25)))];
  }

  function activate(network) {
    root.errorText = "";
    if (network.connected) {
      network.disconnect();
      return;
    }
    if (network.known || !root.needsPassword(network)) {
      network.connect();
      return;
    }
    if (root.isEnterprise(network)) {
      root.errorText = "Enterprise network — connect it once with nmtui.";
      return;
    }
    root.password = "";
    root.pendingNetwork = network;
  }

  function submitPassword() {
    if (!root.pendingNetwork || root.password.length < 1)
      return;
    root.pendingNetwork.connectWithPsk(root.password);
    root.pendingNetwork = null;
    root.password = "";
  }

  Connections {
    target: root.pendingNetwork
    ignoreUnknownSignals: true

    function onConnectionFailed() {
      root.errorText = "Couldn't connect — check the password.";
    }
  }

  // -------------------------------------------------------------- header row
  Item {
    width: parent.width
    height: 24

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "WI-FI"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    // Radio on/off
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 36
      height: 20
      radius: 10
      color: Networking.wifiEnabled ? Theme.accent : Theme.raised

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      Rectangle {
        x: Networking.wifiEnabled ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Networking.wifiEnabled ? Theme.base : Theme.fgDim

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
        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
      }
    }
  }

  // ------------------------------------------------------------- radio is off
  Text {
    width: parent.width
    visible: !Networking.wifiEnabled
    text: Networking.wifiHardwareEnabled ? "Wi-Fi is off." : "Wi-Fi is blocked by the hardware switch."
    wrapMode: Text.WordWrap
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  // -------------------------------------------------------- password prompt
  Column {
    width: parent.width
    spacing: 10
    visible: root.pendingNetwork !== null

    Text {
      width: parent.width
      text: root.pendingNetwork ? root.pendingNetwork.name : ""
      elide: Text.ElideRight
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Theme.fg
    }

    Rectangle {
      width: parent.width
      height: 32
      radius: 8
      color: Theme.raised
      border.width: 1
      border.color: passwordField.activeFocus ? Theme.accent : "transparent"

      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      TextInput {
        id: passwordField

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 34
        verticalAlignment: TextInput.AlignVCenter

        echoMode: revealButton.revealed ? TextInput.Normal : TextInput.Password
        passwordCharacter: "•"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.base
        clip: true

        text: root.password
        onTextChanged: root.password = text

        // Grab the keyboard the moment the prompt appears.
        focus: root.pendingNetwork !== null
        onVisibleChanged: {
          if (visible)
            forceActiveFocus();
        }

        Keys.onReturnPressed: root.submitPassword()
        Keys.onEnterPressed: root.submitPassword()
        Keys.onEscapePressed: {
          root.pendingNetwork = null;
          root.password = "";
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: passwordField.text.length === 0
          text: "Password"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: Theme.fgDim
        }
      }

      // Reveal toggle
      Rectangle {
        id: revealButton

        property bool revealed: false

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 13
        color: "transparent"

        Text {
          anchors.centerIn: parent
          text: revealButton.revealed ? Icons.eyeHide : Icons.eyeShow
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.fgDim
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: revealButton.revealed = !revealButton.revealed
        }
      }
    }

    Row {
      width: parent.width
      spacing: 8
      layoutDirection: Qt.RightToLeft

      Rectangle {
        width: 84
        height: 30
        radius: 8
        color: root.password.length > 0 ? Theme.accent : Theme.raised

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.centerIn: parent
          text: "Connect"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          color: root.password.length > 0 ? Theme.base : Theme.fgDim
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.submitPassword()
        }
      }

      Rectangle {
        width: 76
        height: 30
        radius: 8
        color: cancelHover.containsMouse ? Theme.hover : "transparent"

        Text {
          anchors.centerIn: parent
          text: "Cancel"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: Theme.fgDim
        }

        MouseArea {
          id: cancelHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.pendingNetwork = null;
            root.password = "";
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ network list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 232)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: Networking.wifiEnabled && root.pendingNetwork === null

    Column {
      id: listColumn
      width: parent.width
      spacing: 2

      Repeater {
        model: root.networks

        delegate: Rectangle {
          id: netRow

          required property var modelData
          readonly property bool busy: modelData.stateChanging

          width: listColumn.width
          height: 34
          radius: 9
          color: modelData.connected ? Theme.accentSoft : rowHover.containsMouse ? Theme.hover : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }

          Text {
            id: strengthIcon
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: root.signalGlyph(netRow.modelData.signalStrength)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: netRow.modelData.connected ? Theme.accent : Theme.fg
          }

          Column {
            anchors.left: strengthIcon.right
            anchors.leftMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              width: parent.width
              text: netRow.modelData.name
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: netRow.modelData.connected ? Theme.accent : Theme.fg
            }

            Text {
              width: parent.width
              visible: netRow.busy || netRow.modelData.connected || netRow.modelData.known
              text: netRow.busy ? "Connecting…" : netRow.modelData.connected ? "Connected" : "Saved"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 1
              color: Theme.fgDim
            }
          }

          // Lock badge for anything that isn't an open network.
          Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: root.needsPassword(netRow.modelData) && !netRow.busy
            text: Icons.lock
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize + 1
            color: Theme.fgDim
          }

          // Spinner while NetworkManager works.
          Text {
            id: spinner
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: netRow.busy
            text: Icons.spinner
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Theme.accent

            RotationAnimation on rotation {
              running: netRow.busy
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 900
            }
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activate(netRow.modelData)
          }
        }
      }
    }
  }

  Text {
    width: parent.width
    visible: Networking.wifiEnabled && root.pendingNetwork === null && root.networks.length === 0
    text: "Scanning…"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  // ------------------------------------------------------------------ errors
  Text {
    width: parent.width
    visible: root.errorText.length > 0
    text: root.errorText
    wrapMode: Text.WordWrap
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.crit
  }
}
