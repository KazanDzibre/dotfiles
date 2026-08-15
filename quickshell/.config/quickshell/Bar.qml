// Bar.qml — a floating top bar, one per screen.
//
// The panel itself is transparent; everything visible is an Island, so the
// wallpaper shows through the gaps between groups.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
      // read keystrokes (the Wi-Fi password field, the clipboard search). The
      // rest of the time the bar must not pull focus off your windows.
      focusable: system.wantsKeyboard || tools.wantsKeyboard

      // Holds the compositor awake while IdleInhibit says so. It has to hang
      // off a real window, which is why it lives here and not in the singleton.
      IdleInhibitor {
        window: bar
        enabled: IdleInhibit.enabled
      }

      // Keys are bound in hyprland.conf with `bind = ..., global, quickshell:<name>`.
      GlobalShortcut {
        appid: "quickshell"
        name: "screenshotRegion"
        description: "Select a region to screenshot"
        onPressed: Screenshot.region()
      }

      GlobalShortcut {
        appid: "quickshell"
        name: "screenshotScreen"
        description: "Screenshot the whole screen"
        onPressed: Screenshot.fullScreen()
      }

      GlobalShortcut {
        appid: "quickshell"
        name: "clipboard"
        description: "Open clipboard history"
        onPressed: tools.toggleClipboard()
      }

      GlobalShortcut {
        appid: "quickshell"
        name: "keepAwake"
        description: "Toggle keep awake"
        onPressed: IdleInhibit.toggle()
      }

      // ---------------------------------------------------------------- left
      Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Island {
          id: workspacesIsland

          Workspaces {}
        }

        Island {
          shown: windowTitle.hasWindow

          WindowTitle {
            id: windowTitle

            // The workspace island grows as you open workspaces, which used to
            // push a long title straight through the appearance island. Rather
            // than a fixed cap, take whatever room is actually left: the gap
            // between where this island starts and where the appearance island
            // begins, minus this island's own icon, spacing and padding.
            //
            // Derived from workspacesIsland.width rather than this island's own
            // x, which would be a binding loop.
            maxWidth: Math.max(60, appearanceIsland.x - (Theme.margin + workspacesIsland.width + Theme.gap) - Theme.gap - (Theme.iconSize + 7 + Theme.padding * 2))
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
        id: appearanceIsland

        anchors.right: clockIsland.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        padding: 8
        spacing: 10

        WallpaperButton {}

        ThemeButton {}

        BrightnessButton {}

        AiButton {}
      }

      Island {
        anchors.left: clockIsland.right
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        padding: 8

        WindowsButton {}
      }

      // --------------------------------------------------------------- right
      Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Island {
          ToolsIsland {
            id: tools
          }
        }

        Island {
          shown: Media.hasPlayer

          MediaButton {}
        }

        Island {
          SysInfoIsland {}
        }

        Island {
          shown: tray.hasItems
          padding: 9

          TrayIsland {
            id: tray
            hostWindow: bar
          }
        }

        Island {
          SystemIsland {
            id: system
          }
        }

        Island {
          padding: 8

          NotificationButton {}
        }

        Island {
          padding: 8

          PowerButton {}
        }
      }
    }
  }
}
