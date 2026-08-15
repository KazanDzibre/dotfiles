// ScreenshotOverlay.qml — the selection surface.
//
// Shows a frozen frame of the screen, dimmed, with the selection punched out at
// full brightness. Selecting on a still image rather than the live desktop means
// the picture can't change under you mid-drag.
//
// The overlay is laid out in logical pixels but the captured frame is physical,
// so every coordinate handed to the cropper is scaled by the ratio between them
// — hardcoding 1.5 for this display would break on any other.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
  id: root

  visible: Screenshot.active

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  focusable: true

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: Screenshot.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Physical pixels per logical pixel, derived rather than assumed.
  readonly property real pixelRatio: capture.width > 0 && capture.sourceSize.width > 0 ? capture.sourceSize.width / capture.width : 1

  property real startX: 0
  property real startY: 0
  property real currentX: 0
  property real currentY: 0
  property bool dragging: false

  readonly property real selX: Math.min(startX, currentX)
  readonly property real selY: Math.min(startY, currentY)
  readonly property real selW: Math.abs(currentX - startX)
  readonly property real selH: Math.abs(currentY - startY)

  onVisibleChanged: {
    if (visible) {
      root.dragging = false;
      root.startX = 0;
      root.startY = 0;
      root.currentX = 0;
      root.currentY = 0;
      capture.captureFrame();

      // Whole-screen mode has nothing to select — grab as soon as there is a
      // frame to grab.
      if (Screenshot.mode === "screen")
        wholeScreenTimer.restart();
    }
  }

  Timer {
    id: wholeScreenTimer
    interval: 120
    onTriggered: root.commit(0, 0, capture.sourceSize.width, capture.sourceSize.height)
  }

  ScreencopyView {
    id: capture

    anchors.fill: parent
    captureSource: root.screen
    live: false
  }

  // Dimming is four rectangles framing the selection rather than a second
  // capture composited on top — one frame grab, and the selected area is
  // simply never covered.
  readonly property bool hasSelection: Screenshot.mode === "region" && root.selW >= 1 && root.selH >= 1

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.45)
    visible: Screenshot.mode === "region" && !root.hasSelection
  }

  Repeater {
    model: 4

    delegate: Rectangle {
      required property int index

      color: Qt.rgba(0, 0, 0, 0.45)
      visible: root.hasSelection

      // 0 above, 1 below, 2 left, 3 right of the selection.
      x: index === 3 ? root.selX + root.selW : index === 2 ? 0 : 0
      y: index === 0 ? 0 : index === 1 ? root.selY + root.selH : root.selY
      width: index < 2 ? root.width : index === 2 ? root.selX : root.width - (root.selX + root.selW)
      height: index === 0 ? root.selY : index === 1 ? root.height - (root.selY + root.selH) : root.selH
    }
  }

  Rectangle {
    x: root.selX
    y: root.selY
    width: root.selW
    height: root.selH
    color: "transparent"
    border.width: 1
    border.color: Theme.accent
    visible: Screenshot.mode === "region" && root.selW > 0 && root.selH > 0
  }

  // Live dimensions next to the cursor.
  Rectangle {
    x: Math.min(root.width - width - 8, root.selX + root.selW + 10)
    y: Math.min(root.height - height - 8, root.selY + root.selH + 10)
    width: sizeLabel.implicitWidth + 16
    height: 24
    radius: 8
    color: Theme.island
    border.width: 1
    border.color: Theme.border
    visible: root.dragging && root.selW > 1

    Text {
      id: sizeLabel
      anchors.centerIn: parent
      text: Math.round(root.selW * root.pixelRatio) + " × " + Math.round(root.selH * root.pixelRatio)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fg
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Theme.barHeight + 24
    visible: Screenshot.mode === "region" && !root.dragging && root.selW < 1
    text: "Drag to select  ·  Esc to cancel"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    opacity: 0.75
  }

  MouseArea {
    anchors.fill: parent
    enabled: Screenshot.mode === "region"
    cursorShape: Qt.CrossCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: event => {
      if (event.button === Qt.RightButton) {
        Screenshot.cancel();
        return;
      }
      root.startX = event.x;
      root.startY = event.y;
      root.currentX = event.x;
      root.currentY = event.y;
      root.dragging = true;
    }

    onPositionChanged: event => {
      if (root.dragging) {
        root.currentX = event.x;
        root.currentY = event.y;
      }
    }

    onReleased: {
      if (!root.dragging)
        return;
      root.dragging = false;
      root.commit(root.selX * root.pixelRatio, root.selY * root.pixelRatio, root.selW * root.pixelRatio, root.selH * root.pixelRatio);
    }
  }

  Item {
    focus: root.visible
    Keys.onEscapePressed: Screenshot.cancel()
  }

  // Grab the frozen frame at full resolution and hand the crop box to the
  // cropper. Done here rather than in the singleton because grabToImage only
  // works on an item that is actually being rendered.
  function commit(x, y, width, height) {
    const path = "/tmp/quickshell-screenshot-" + Date.now() + ".png";

    capture.grabToImage(function (result) {
      result.saveToFile(path);
      Screenshot.finish(path, x, y, width, height);
    }, Qt.size(capture.sourceSize.width, capture.sourceSize.height));
  }
}
