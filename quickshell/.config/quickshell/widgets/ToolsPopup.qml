// ToolsPopup.qml — apps & tools, the launcher grid that used to sit at the
// bottom of the control center and made it too tall. Opened from the control
// center's "Apps & tools" row; richer panels (Dashboard, Windows, Clipboard…)
// are asked for through `panelRequested`, which StatusCluster.qml answers.
import QtQuick
import Quickshell
import qs

MorphPanel {
  id: root

  cardWidth: 372
  align: "right"
  contentSpacing: 12

  signal panelRequested(string name)

  readonly property int inner: cardWidth - 28

  function request(name) {
    root.panelRequested(name);
  }

  component Launcher: Rectangle {
    id: launcher

    property string glyph
    property string label
    property bool lit: false
    property int badge: 0
    signal activated(int button)

    width: (root.inner - 24) / 4
    height: 60
    radius: 14
    color: launchArea.containsMouse ? Theme.accentSoft : Theme.raised
    scale: launchArea.pressed ? 0.93 : 1
    transform: Translate {
      y: launchArea.containsMouse ? -2 : 0
      Behavior on y {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutBack
        }
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
    Behavior on scale {
      SpringAnimation {
        spring: 6
        damping: 0.3
        epsilon: 0.002
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: launcher.glyph
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize + 2
        color: launcher.lit || launchArea.containsMouse ? Theme.accent : Theme.fg
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: launcher.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: launchArea.containsMouse ? Theme.accent : Theme.fgDim
      }
    }

    Rectangle {
      visible: launcher.badge > 0
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 6
      width: Math.max(16, badgeText.implicitWidth + 8)
      height: 16
      radius: 8
      color: Theme.accent

      Text {
        id: badgeText
        anchors.centerIn: parent
        text: launcher.badge > 99 ? "99+" : launcher.badge
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize - 1
        font.bold: true
        color: Theme.base
      }
    }

    MouseArea {
      id: launchArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: event => launcher.activated(event.button)
    }
  }

  Text {
    text: "APPS & TOOLS"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    font.bold: true
    font.letterSpacing: 1
    color: Theme.fgDim
  }

  Grid {
    columns: 4
    spacing: 8

    // Left click is the web app, right click the native chat — as the old
    // bar button did.
    Launcher {
      glyph: Icons.ai
      label: "AI"
      lit: AiChat.open || AiAssistant.shown
      onActivated: button => {
        root.close();
        if (button === Qt.RightButton) {
          Dashboard.close();
          AiChat.toggle();
          return;
        }
        AiChat.close();
        AiAssistant.toggle();
      }
    }

    Launcher {
      glyph: Icons.dashboard
      label: "Dashboard"
      lit: Dashboard.open
      onActivated: root.request("dashboard")
    }

    Launcher {
      glyph: Icons.sineWave
      label: "Tones"
      lit: Tones.active || Tones.timing
      onActivated: root.request("tones")
    }

    Launcher {
      glyph: Icons.windows
      label: "Windows"
      onActivated: root.request("windows")
    }

    Launcher {
      glyph: Icons.crop
      label: "Screenshot"
      onActivated: button => {
        root.close();
        shotDelay.whole = button === Qt.RightButton;
        shotDelay.restart();
      }
    }

    // Left click records the screen, right click picks a region.
    Launcher {
      glyph: Icons.record
      label: Recorder.recording ? "Stop" : "Record"
      lit: Recorder.recording
      onActivated: button => {
        root.close();
        recordDelay.region = button === Qt.RightButton;
        recordDelay.restart();
      }
    }

    Launcher {
      glyph: Sounds.enabled ? Icons.volHigh : Icons.volMute
      label: "Sounds"
      lit: Sounds.enabled
      onActivated: Sounds.toggle()
    }

    Launcher {
      glyph: Icons.clipboard
      label: "Clipboard"
      onActivated: root.request("clipboard")
    }

    Launcher {
      glyph: Icons.chip
      label: "System"
      onActivated: root.request("system")
    }

    Launcher {
      glyph: Icons.updates
      label: "Updates"
      badge: Updates.count
      lit: Updates.installing
      // Left click installs (progress shows in the island); right click
      // opens the list of what's pending.
      onActivated: button => {
        if (button === Qt.RightButton) {
          root.request("updates");
          return;
        }
        root.close();
        Updates.install();
      }
    }

    Launcher {
      glyph: Icons.keyboard
      label: "Shortcuts"
      onActivated: root.request("shortcuts")
    }

    Launcher {
      visible: Drives.hasDrives
      glyph: Icons.usbDrive
      label: "Drives"
      onActivated: root.request("drives")
    }
  }

  Timer {
    id: recordDelay
    property bool region: false
    interval: 320
    onTriggered: Recorder.toggle(region)
  }

  // Let this card get out of the frame before the capture starts.
  Timer {
    id: shotDelay
    property bool whole: false
    interval: 320
    onTriggered: whole ? Screenshot.fullScreen() : Screenshot.region()
  }
}
