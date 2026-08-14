// NotificationToasts.qml — transient popups under the right end of the bar.
//
// A layer-shell window rather than a Popup, because toasts have to appear
// without anything being clicked. It ignores the exclusion zone so it floats
// over windows instead of resizing them, and it only exists while there is
// something to show.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
  id: root

  visible: Notifications.toasts.length > 0

  anchors {
    top: true
    right: true
  }

  margins {
    top: Theme.barHeight + Theme.gap
    right: Theme.margin
  }

  implicitWidth: 350
  implicitHeight: Math.max(1, stack.implicitHeight)

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  Column {
    id: stack

    width: parent.width
    spacing: Theme.gap

    Repeater {
      model: Notifications.toasts

      delegate: NotificationCard {
        id: toast

        required property var modelData

        notification: modelData
        standalone: true
        showAge: false

        onDismissed: Notifications.dismiss(toast.modelData)

        // Slide in from the right.
        opacity: 0
        x: 40

        Component.onCompleted: {
          opacity = 1;
          x = 0;
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animSlow
          }
        }
        Behavior on x {
          NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.OutQuint
          }
        }

        // The sender's expiry, honoured but bounded: apps ask for anything from
        // zero to forever, and neither extreme is useful on a bar.
        Timer {
          running: !hoverCatcher.containsMouse
          interval: {
            const requested = toast.modelData.expireTimeout;
            if (requested === 0)
              return 5000;                       // 0 means "server decides"
            if (requested < 0)
              return 8000;                       // negative means "never"
            return Math.max(2500, Math.min(15000, requested));
          }
          onTriggered: Notifications.popToast(toast.modelData)
        }

        // Hovering pauses the countdown so a notification can't vanish while
        // you are reading it or reaching for one of its buttons.
        MouseArea {
          id: hoverCatcher
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          z: -1
        }
      }
    }
  }
}
