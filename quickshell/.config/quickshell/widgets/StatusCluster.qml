// StatusCluster.qml — Wi-Fi, Bluetooth, volume and battery at a glance; click
// for the control center.
//
// This is also where every panel the bar used to hang off its own button now
// lives: the control center asks for one by name (panelRequested) and it opens
// here, under the cluster. The island asks the same way, through
// Moments.popupRequested, for the screen it is on.
//
// Scroll changes the volume, right click mutes.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs

Item {
  id: root

  property var barScreen

  // Every panel here grows out of this pill: its width on the bar, i.e. this
  // item plus the Island's padding.
  readonly property real pillWidth: implicitWidth + Theme.padding * 2

  // True while any panel is out of the pill (open, or still shrinking back).
  // The bar hides the real pill meanwhile: the panel has become it.
  readonly property bool panelOut: cc.visible || wifiPopup.visible || bluetoothPopup.visible || volumePopup.visible || brightnessPopup.visible || tonesPopup.visible || windowsPopup.visible || clipboardPopup.visible || sysInfoPopup.visible || updatesPopup.visible || drivesPopup.visible || notificationPopup.visible

  // The bar takes keyboard focus only while one of these needs typing.
  readonly property bool wantsKeyboard: wifiPopup.wantsKeyboard || clipboardPopup.wantsKeyboard

  implicitWidth: face.implicitWidth
  implicitHeight: 18

  function toggleClipboard() {
    clipboardPopup.toggle();
  }

  // From a detail panel back to the control center: it folds into the pill
  // while the control center grows back out.
  function backToCenter(panel) {
    panel.leave(-1, () => cc.enterFrom(panel.shapeWidth, panel.shapeHeight, -1));
  }

  function openPanel(name) {
    const panels = {
      wifi: wifiPopup,
      bluetooth: bluetoothPopup,
      volume: volumePopup,
      brightness: brightnessPopup,
      tones: tonesPopup,
      windows: windowsPopup,
      clipboard: clipboardPopup,
      system: sysInfoPopup,
      updates: updatesPopup,
      drives: drivesPopup,
      notifications: notificationPopup
    };
    if (name === "wallpaper") {
      cc.close();
      picker.open();
      return;
    }
    if (!panels[name])
      return;
    // One panel at a time, after the control center has started to fold away.
    for (const key in panels) {
      if (key !== name)
        panels[key].close();
    }
    // From the control center: slide across into it, one surface.
    if (cc.opened) {
      const target = panels[name];
      cc.leave(1, () => target.enterFrom(cc.shapeWidth, cc.shapeHeight, 1));
      return;
    }
    openDelay.open(panels[name]);
  }

  Timer {
    id: openDelay
    property var target: null
    interval: 90
    function open(panel) {
      target = panel;
      restart();
    }
    onTriggered: if (target)
      target.open()
  }

  readonly property var audio: face.audio

  StatusFace {
    id: face
    anchors.centerIn: parent
    lit: cc.opened || area.containsMouse
  }

  MouseArea {
    id: area
    anchors.fill: parent
    anchors.margins: -6
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      if (event.button === Qt.RightButton) {
        if (root.audio)
          root.audio.muted = !root.audio.muted;
        return;
      }
      cc.toggle();
    }

    onWheel: wheel => {
      if (!root.audio)
        return;
      const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
      root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + step));
    }
  }

  // ----------------------------------------------------------------- panels
  // Grows out of this pill. Its width is this item plus the Island's padding.
  ControlCenter {
    id: cc
    screen: root.barScreen
    pillWidth: root.pillWidth
    onPanelRequested: name => root.openPanel(name)
  }

  WifiPopup {
    id: wifiPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(wifiPopup)
  }

  BluetoothPopup {
    id: bluetoothPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(bluetoothPopup)
  }

  VolumePopup {
    id: volumePopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(volumePopup)
  }

  BrightnessPopup {
    id: brightnessPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(brightnessPopup)
    align: "right"
  }

  TonesPopup {
    id: tonesPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(tonesPopup)
    align: "right"
  }

  WindowsPopup {
    id: windowsPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(windowsPopup)
    align: "right"
  }

  ClipboardPopup {
    id: clipboardPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(clipboardPopup)
  }

  SysInfoPopup {
    id: sysInfoPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(sysInfoPopup)
    align: "right"
  }

  UpdatesPopup {
    id: updatesPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(updatesPopup)
    align: "right"
  }

  // The full history, reached from the island's "open all" and the control
  // center's Do not disturb tile, now that the bar has no bell.
  NotificationPopup {
    id: notificationPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(notificationPopup)
  }

  DrivesPopup {
    id: drivesPopup
    screen: root.barScreen
    pillWidth: root.pillWidth
    showBack: true
    onBack: root.backToCenter(drivesPopup)
    align: "right"
  }

  // The wallpaper picker used to live on its own bar button; it is per screen,
  // so it lives with this screen's cluster now.
  WallpaperPicker {
    id: picker
    screen: root.barScreen
  }

  Connections {
    target: Wallpaper

    function onPickerToggleRequested(screenName) {
      if (root.barScreen && root.barScreen.name === screenName)
        picker.toggle();
    }
  }

  Connections {
    target: Moments

    function onPopupRequested(name, screenName) {
      if (root.barScreen && root.barScreen.name === screenName)
        root.openPanel(name);
    }
  }
}
