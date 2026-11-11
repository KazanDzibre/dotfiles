// Bar.qml — a floating top bar, one per screen.
//
// The panel itself is transparent; everything visible is an Island, so the
// wallpaper shows through the gaps between groups.
//
// Deliberately sparse: workspaces and the focused window on the left, the
// dynamic island in the middle (its own window — see DynamicIsland.qml), and on
// the right only the tray and the status cluster. Notifications live in the
// island; everything else in the control center the status cluster opens.
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

      // The island is a separate window on the same layer, and this one would
      // otherwise swallow every click on it (transparent or not). So the bar
      // takes input everywhere except a hole in the middle where the island sits.
      // The hole reaches further right while bubbles sit beside the island.
      mask: Region {
        width: bar.width
        height: bar.height

        Region {
          intersection: Intersection.Subtract
          x: bar.width / 2 - 260
          width: 260 + Math.max(260, island.rightReach + 8)
          height: bar.height
        }
      }
      color: "transparent"

      // Only take keyboard focus while something on the bar actually needs to
      // read keystrokes (the Wi-Fi password field, the clipboard search). The
      // rest of the time the bar must not pull focus off your windows.
      focusable: status.wantsKeyboard

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
        onPressed: status.toggleClipboard()
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

          dropDelay: 0
          id: workspacesIsland

          // Each bar lists only its own screen's workspaces, so the three
          // monitors do not all show the same row.
          Workspaces {
            barScreen: bar.screen
          }
        }

        // Its own pill, so a window switch only ever resizes this one.
        Island {
          dropDelay: 70
          id: titleIsland

          shown: windowTitle.present
          tappable: true
          onTapped: switcher.toggle()
          // The switcher grows out of this exact spot and wears its face, so
          // the pill is "in" the panel while it's out.
          opacity: switcher.visible ? 0 : shown ? 1 : 0

          WindowTitle {
            id: windowTitle

            // Whatever room is left before the hole the island sits in (520px
            // around the centre), minus the workspaces pill and this pill's
            // own icon, spacing and padding.
            maxWidth: Math.max(60, bar.width / 2 - 270 - Theme.margin - workspacesIsland.width - Theme.gap - (Theme.iconSize + 7) - Theme.padding * 2)
          }
        }
      }

      WindowSwitcher {
        id: switcher
        screen: bar.screen
        pillLeft: Theme.margin + titleIsland.x
        pillWidth: titleIsland.width

        face: Component {
          WindowTitle {
            maxWidth: windowTitle.maxWidth
          }
        }
      }

      // SUPER+Tab: every workspace on this screen, side by side.
      WorkspaceOverview {
        screen: bar.screen
      }

      // -------------------------------------------------------------- centre
      DynamicIsland {
        id: island
        screen: bar.screen
      }

      // --------------------------------------------------------------- right
      Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        // Only while a USB drive is plugged in.
        Island {
          dropDelay: 260
          shown: Drives.hasDrives
          padding: 8

          DrivesButton {}
        }

        Island {

          dropDelay: 300
          shown: tray.hasItems
          padding: 9

          TrayIsland {
            id: tray
            hostWindow: bar
          }
        }

        // Hidden while one of its panels is out: the panel grows from this exact
        // spot wearing the same face, so the pill is "in" the panel meanwhile.
        Island {
          dropDelay: 340
          opacity: status.panelOut ? 0 : 1
          // Keep its place in the row while invisible, or the tray would
          // slide over into the gap.
          visible: true

          StatusCluster {
            id: status
            barScreen: bar.screen
          }
        }

        // The screen recording lives here, not in the centre island, so the
        // island stays free while recording. Gone when not recording.
        Island {
          dropDelay: 380
          shown: Recorder.recording
          padding: 10

          RecordButton {}
        }
      }
    }
  }
}
