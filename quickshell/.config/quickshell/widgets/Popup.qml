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

  // Whether the card *wants* to be on screen. Deliberately separate from
  // `visible`, which is the Wayland surface and has to outlive this by the
  // length of the close animation. Anything reacting to a popup opening or
  // closing should watch this, not `visible`.
  property bool opened: false

  default property alias content: inner.data

  // How far the card falls on the way in. The window grows by the same amount
  // so the slide isn't clipped, and the anchor moves up to match, which leaves
  // the card resting exactly where it always did.
  readonly property int lift: 8
  // Room underneath for the settle to overshoot into.
  readonly property int slack: 4

  anchor.item: anchorItem
  anchor.rect.x: {
    if (!anchorItem)
      return 0;
    if (align === "right")
      return anchorItem.width - root.implicitWidth;
    return Math.round((anchorItem.width - root.implicitWidth) / 2);
  }
  anchor.rect.y: anchorItem ? anchorItem.height + Theme.padding + Theme.margin - root.lift : 0

  implicitWidth: cardWidth
  implicitHeight: card.implicitHeight + lift + slack
  color: "transparent"

  // A PopupWindow is gone the frame `visible` goes false, so binding that
  // straight to the open state means the exit animation never renders. Hold the
  // surface up until the card has actually faded out.
  visible: opened || card.opacity > 0.001

  // Take input only where the card actually rests. Without this the travel room
  // above and below it would be transparent but still clickable, so clicking
  // the gap under the bar would fail to dismiss the popup. Deliberately the
  // resting rect rather than `item: card`, so it doesn't churn every frame of
  // the animation.
  mask: Region {
    y: root.lift
    width: root.width
    height: card.implicitHeight
  }

  function toggle() {
    root.opened = !root.opened;
  }

  function open() {
    root.opened = true;
  }

  function close() {
    root.opened = false;
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
      if (!root.opened || grab.active || attempts > 25) {
        stop();
        return;
      }
      attempts++;
      grab.active = true;
    }
  }

  // Deliberately a Connections block rather than an `onOpenedChanged` handler:
  // components deriving from Popup define their own, which would override ours.
  Connections {
    target: root

    function onOpenedChanged() {
      if (root.opened) {
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

    // The closed pose. `open` below is the resting one; everything animates
    // between the two.
    y: 0
    opacity: 0
    scale: 0.94
    transformOrigin: Item.Top

    states: State {
      name: "open"
      when: root.opened

      PropertyChanges {
        card.y: root.lift
        card.opacity: 1
        card.scale: 1
      }
      PropertyChanges {
        inner.opacity: 1
      }
    }

    // Asymmetric on purpose: opening is a spring you watch land, closing is a
    // dismissal that shouldn't keep you waiting.
    transitions: [
      Transition {
        to: "open"

        NumberAnimation {
          target: card
          property: "opacity"
          duration: Theme.animFast
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: card
          properties: "y,scale"
          duration: Theme.animSlow
          easing.type: Easing.OutBack
          easing.overshoot: 1.2
        }
        // Content trails the card by a frame or two, so the surface arrives
        // first and fills in rather than everything blooming at once.
        SequentialAnimation {
          PauseAnimation {
            duration: 50
          }
          NumberAnimation {
            target: inner
            property: "opacity"
            duration: Theme.animFast
            easing.type: Easing.OutCubic
          }
        }
      },
      Transition {
        from: "open"

        NumberAnimation {
          targets: [card, inner]
          property: "opacity"
          duration: Theme.animFast
          easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: card
          properties: "y,scale"
          duration: Theme.animFast
          easing.type: Easing.InCubic
        }
      }
    ]

    Column {
      id: inner
      anchors.centerIn: parent
      width: parent.width - 28
      spacing: 12
      opacity: 0
    }
  }
}
