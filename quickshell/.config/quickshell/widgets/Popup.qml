// Popup.qml — the card that drops out of a bar island.
//
// Handles anchoring, the open/close animation, and dismiss-on-click-outside via
// Hyprland's focus grab. Put content in it like any Column.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

PopupWindow {
  id: root

  property Item anchorItem
  property int cardWidth: 300
  property alias contentSpacing: inner.spacing
  // "center" hangs the card under the middle of the anchor; "right" lines their
  // right edges up, which keeps islands near the screen edge on-screen.
  property string align: "center"

  default property alias content: inner.data

  anchor.item: anchorItem
  anchor.rect.x: {
    if (!anchorItem)
      return 0;
    if (align === "right")
      return anchorItem.width - root.implicitWidth;
    return Math.round((anchorItem.width - root.implicitWidth) / 2);
  }
  anchor.rect.y: anchorItem ? anchorItem.height + Theme.padding + Theme.margin : 0

  implicitWidth: cardWidth
  implicitHeight: card.implicitHeight
  color: "transparent"
  visible: false

  function toggle() {
    root.visible = !root.visible;
  }

  function close() {
    root.visible = false;
  }

  // Clicking anywhere else drops the grab, which is our cue to close.
  HyprlandFocusGrab {
    id: grab
    windows: [root]

    onCleared: root.close()
  }

  // Hyprland refuses a grab for a surface it hasn't mapped yet, and refuses it
  // *silently* — `active` just stays false. So rather than binding it, ask
  // repeatedly until it sticks, then stop.
  Timer {
    id: armGrab

    property int attempts: 0

    interval: 40
    repeat: true

    onTriggered: {
      if (!root.visible || grab.active || attempts > 25) {
        stop();
        return;
      }
      attempts++;
      grab.active = true;
    }
  }

  // Deliberately a Connections block rather than an `onVisibleChanged` handler:
  // components deriving from Popup define their own, which would override ours.
  Connections {
    target: root

    function onVisibleChanged() {
      if (root.visible) {
        armGrab.attempts = 0;
        armGrab.restart();
      } else {
        armGrab.stop();
        grab.active = false;
      }
    }
  }

  Rectangle {
    id: card

    width: parent.width
    implicitHeight: inner.implicitHeight + 28
    height: implicitHeight

    radius: 16
    color: Theme.island
    border.width: 1
    border.color: Theme.border

    opacity: root.visible ? 1 : 0
    scale: root.visible ? 1 : 0.94
    transformOrigin: Item.Top

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutBack
      }
    }

    Column {
      id: inner
      anchors.centerIn: parent
      width: parent.width - 28
      spacing: 12
    }
  }
}
