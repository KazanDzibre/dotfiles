// WorkspacePreview.qml — the live thumbnail that grows out of a workspace dot.
//
// Each window is captured separately and placed where it sits on that
// workspace, over the current wallpaper. Captures refresh about once a second
// rather than every frame: a dozen full-rate captures would cost far more than
// a thumbnail is worth.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

PanelWindow {
  id: root

  property var barScreen
  screen: barScreen

  signal chosen(var workspace)

  property var workspace: null
  property bool shown: false
  property real targetX: 0

  // Moving from one dot to the next, or from a dot onto the card, shouldn't
  // close it, so hiding waits a moment.
  function showFor(ws, x) {
    hideTimer.stop();
    root.targetX = Math.max(4, x - 30);
    if (!root.shown) {
      Hyprland.refreshToplevels();
      root.workspace = ws;
      root.shown = true;
    } else if (ws !== root.workspace) {
      root.pendingWs = ws;
      swap.restart();
    }
  }

  function hideSoon() {
    hideTimer.restart();
  }

  function hideNow() {
    hideTimer.stop();
    root.shown = false;
  }

  property var pendingWs: null

  Timer {
    id: hideTimer
    interval: 200
    onTriggered: root.shown = false
  }

  SequentialAnimation {
    id: swap
    NumberAnimation {
      target: shot
      property: "opacity"
      to: 0
      duration: 80
    }
    ScriptAction {
      script: root.workspace = root.pendingWs
    }
    NumberAnimation {
      target: shot
      property: "opacity"
      to: 1
      duration: 180
    }
  }

  readonly property var windows: workspace ? Array.from(Hyprland.toplevels.values).filter(t => t.workspace && t.workspace.id === workspace.id && t.wayland) : []

  anchors {
    top: true
    left: true
  }
  implicitWidth: 520
  implicitHeight: 290
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  focusable: false

  WlrLayershell.namespace: "quickshell:workspace-preview"
  WlrLayershell.layer: WlrLayer.Top

  visible: shown || card.opacity > 0.01

  mask: Region {
    x: root.shown ? card.x : 0
    y: root.shown ? card.y : 0
    width: root.shown ? card.width : 0
    height: root.shown ? card.height : 0
  }

  Rectangle {
    id: card

    x: root.targetX
    y: Theme.barHeight + 2
    width: 336
    height: 236
    radius: 20
    color: Theme.island
    border.width: 1
    border.color: Theme.border

    opacity: 0
    scale: 0.25
    transformOrigin: Item.TopLeft

    states: State {
      name: "shown"
      when: root.shown
      PropertyChanges {
        card.opacity: 1
        card.scale: 1
      }
    }

    transitions: [
      Transition {
        to: "shown"
        NumberAnimation {
          property: "opacity"
          duration: 220
        }
        NumberAnimation {
          property: "scale"
          duration: 560
          easing.type: Easing.BezierSpline
          easing.bezierCurve: [0.34, 1.32, 0.5, 1, 1, 1]
        }
      },
      Transition {
        from: "shown"
        NumberAnimation {
          properties: "opacity,scale"
          duration: 200
          easing.type: Easing.InCubic
        }
      }
    ]

    Behavior on x {
      enabled: root.shown
      NumberAnimation {
        duration: 420
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: hideTimer.stop()
      onExited: root.hideSoon()
      onClicked: {
        root.chosen(root.workspace);
        root.hideNow();
      }
    }

    ClippingRectangle {
      id: shot

      x: 10
      y: 10
      width: 316
      height: 190
      radius: 13
      color: Theme.raised

      readonly property real factor: root.screen ? width / root.screen.width : 0.25

      Image {
        anchors.fill: parent
        source: Wallpaper.current ? "file://" + Wallpaper.thumbFor(Wallpaper.current) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 720
      }

      Repeater {
        // Kept while fading out, so the windows leave with the card.
        model: root.visible ? root.windows : []

        delegate: Rectangle {
          id: thumb

          required property var modelData
          readonly property var info: modelData.lastIpcObject

          x: info && info.at ? (info.at[0] - root.screen.x) * shot.factor : 0
          y: info && info.at ? (info.at[1] - root.screen.y) * shot.factor : 0
          width: info && info.size ? info.size[0] * shot.factor : shot.width
          height: info && info.size ? info.size[1] * shot.factor : shot.height
          radius: 4
          color: Theme.base

          // Stands in until the capture lands, or if it can't be captured.
          IconImage {
            anchors.centerIn: parent
            visible: !capture.hasContent
            implicitSize: 26
            source: Icons.themeIconFor(thumb.modelData.wayland.appId)
          }

          ScreencopyView {
            id: capture
            anchors.fill: parent
            captureSource: thumb.modelData.wayland
            live: false
            constraintSize: Qt.size(Math.max(1, Math.round(thumb.width * 2)), Math.max(1, Math.round(thumb.height * 2)))
            Component.onCompleted: captureFrame()
          }

          Timer {
            running: root.shown
            repeat: true
            interval: 1000
            onTriggered: capture.captureFrame()
          }
        }
      }
    }

    Item {
      x: 18
      y: 204
      width: parent.width - 36
      height: 22

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.workspace ? "Workspace " + root.workspace.name : ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.windows.length === 0 ? "Empty" : root.windows.length === 1 ? "1 window" : root.windows.length + " windows"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize + 1
        color: Theme.fgDim
      }
    }
  }
}
