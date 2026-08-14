// TrayIsland.qml — StatusNotifierItem tray icons.
//
// Left click activates, middle click is the app's secondary action, right click
// opens its own DBus menu. The menu is rendered by Quickshell's menu layer, so
// it needs the host window and a position within it — hence hostWindow, which
// Bar.qml passes down.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

Row {
  id: root

  property var hostWindow: null

  readonly property var items: SystemTray.items ? Array.from(SystemTray.items.values) : []
  readonly property bool hasItems: items.length > 0

  spacing: 9

  Repeater {
    model: root.items

    delegate: Item {
      id: entry

      required property var modelData

      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18

      IconImage {
        id: icon
        anchors.fill: parent
        source: entry.modelData.icon
        asynchronous: true
        // Items that need attention shouldn't blend in with the rest.
        opacity: mouse.containsMouse ? 1.0 : entry.modelData.status === Status.Passive ? 0.55 : 0.85

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animFast
          }
        }
      }

      // Ring for anything asking to be noticed.
      Rectangle {
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 11
        color: "transparent"
        border.width: 1
        border.color: Theme.crit
        visible: entry.modelData.status === Status.NeedsAttention

        SequentialAnimation on opacity {
          running: entry.modelData.status === Status.NeedsAttention
          loops: Animation.Infinite

          NumberAnimation {
            to: 0.3
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

      MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: event => {
          const item = entry.modelData;

          if (event.button === Qt.MiddleButton) {
            item.secondaryActivate();
            return;
          }

          // Some items are menu-only and have nothing to activate.
          if (event.button === Qt.RightButton || item.onlyMenu) {
            if (item.hasMenu && root.hostWindow) {
              const point = entry.mapToItem(null, entry.width / 2, entry.height + Theme.margin);
              item.display(root.hostWindow, Math.round(point.x), Math.round(point.y));
            }
            return;
          }

          item.activate();
        }
      }
    }
  }
}
