// Bar.qml — a floating top bar, one per screen.
//
// The panel itself is transparent; everything visible is an Island, so the
// wallpaper shows through the gaps between groups.
import Quickshell
import QtQuick
import qs
import qs.widgets

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar

      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: Theme.barHeight
      color: "transparent"

      // Only take keyboard focus while something on the bar actually needs to
      // read keystrokes (the Wi-Fi password field). The rest of the time the
      // bar must not pull focus off your windows.
      focusable: system.wantsKeyboard

      // ---------------------------------------------------------------- left
      Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Island {
          Workspaces {}
        }

        Island {
          shown: windowTitle.hasWindow

          WindowTitle {
            id: windowTitle
            // Kept tight so a long title can't reach the centred clock.
            maxWidth: 160
          }
        }
      }

      // -------------------------------------------------------------- centre
      Island {
        id: clockIsland

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Clock {}
      }

      // Hung off the clock's left edge rather than placed in a row with it, so
      // the clock itself stays exactly centred on the screen.
      Island {
        anchors.right: clockIsland.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        padding: 8

        WallpaperButton {}
      }

      // --------------------------------------------------------------- right
      Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Island {
          shown: media.hasPlayer

          MediaIsland {
            id: media
            maxWidth: 130
          }
        }

        Island {
          SysInfoIsland {}
        }

        Island {
          SystemIsland {
            id: system
          }
        }
      }
    }
  }
}
