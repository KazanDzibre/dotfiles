// MorphPanel.qml — a panel that grows out of a bar pill, the way the island
// grows (same curve, same timing).
//
// Closed, the shape sits exactly on top of the status pill, wearing the same
// face, so there is no seam: as it springs open (leftwards and down) the pill's
// icons dissolve into it and the panel's content fades in, so the pill becomes
// the panel rather than sitting on top of it. Closing runs it all back into the
// pill, then the shape hides and the real pill on the bar shows again.
//
// It mirrors Popup.qml's API (opened / open() / close() / toggle(), a default
// property for content, cardWidth, contentSpacing), so a panel can switch
// between the two by changing its base type.
//
// Placed at the top-right of its screen: the pill is assumed to be the bar's
// right-most island.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

PanelWindow {
  id: root

  // ------------------------------------------------------------------- api
  property bool opened: false
  property int cardWidth: 360
  property alias contentSpacing: body.spacing
  default property alias content: body.data

  // Accepted for compatibility with Popup.qml, so a panel can switch base type
  // without edits. Position comes from the pill instead.
  property Item anchorItem
  property string align: "right"

  // Panels with a text field that should take typing as soon as they open
  // (the clipboard search) set this; others get focus when clicked.
  property bool grabKeyboard: false

  // Detail panels reached from the control center show a "‹ Control center"
  // link at the top; clicking it emits `back` (StatusCluster.qml handles it).
  property bool showBack: false
  signal back
  readonly property real backHeight: showBack ? 30 : 0

  // ---------------------------------------------------- moving between panels
  // Going from one panel to another doesn't fold back into the pill: the old
  // one's content slides away, and the new one takes over at exactly the old
  // one's size, then springs to its own while its content slides in — one
  // surface navigating, like going deeper into Settings. StatusCluster.qml
  // drives it with leave() on one panel and enterFrom() on the next.
  readonly property real shapeWidth: shape.width
  readonly property real shapeHeight: shape.height

  property bool snap: false        // size changes jump instead of animating
  property bool useStart: false
  property real startW: 0
  property real startH: 0
  property real slide: 0           // content offset while sliding
  property bool manual: false      // content opacity driven by the slide
  property real manualOpacity: 1
  property bool leaving: false
  property var leaveThen: null

  // Normal open/close: content fades with the shape.
  property real autoOpacity: opened ? 1 : 0
  Behavior on autoOpacity {
    NumberAnimation {
      duration: root.opened ? 200 : 120
    }
  }

  function enterFrom(w, h, dir) {
    root.snap = true;
    root.startW = w;
    root.startH = h;
    root.useStart = true;
    root.manual = true;
    root.manualOpacity = 0;
    root.slide = 36 * dir;
    root.opened = true;
    // One frame at the old panel's size, then spring to ours.
    enterRelease.restart();
  }

  function leave(dir, then) {
    root.leaving = true;
    armGrab.stop();
    grab.active = false;
    root.leaveThen = then;
    root.manualOpacity = body.opacity;
    root.manual = true;
    slideOut.dir = dir;
    slideOut.restart();
  }

  Timer {
    id: enterRelease
    interval: 16
    onTriggered: {
      root.snap = false;
      root.useStart = false;
      slideIn.restart();
    }
  }

  ParallelAnimation {
    id: slideIn
    SequentialAnimation {
      PauseAnimation {
        duration: 90
      }
      NumberAnimation {
        target: root
        property: "manualOpacity"
        to: 1
        duration: 260
        easing.type: Easing.OutQuad
      }
    }
    NumberAnimation {
      target: root
      property: "slide"
      to: 0
      duration: 520
      easing.type: Easing.BezierSpline
      easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }
    onFinished: root.manual = false
  }

  ParallelAnimation {
    id: slideOut
    property int dir: 1
    NumberAnimation {
      target: root
      property: "manualOpacity"
      to: 0
      duration: 160
      easing.type: Easing.OutQuad
    }
    NumberAnimation {
      target: root
      property: "slide"
      to: -36 * slideOut.dir
      duration: 200
      easing.type: Easing.InCubic
    }
    onFinished: {
      if (root.leaveThen)
        root.leaveThen();
      root.leaveThen = null;
      vanish.restart();
    }
  }

  // The next panel is mapped on top by now; drop this one without shrinking.
  Timer {
    id: vanish
    interval: 70
    onTriggered: {
      root.snap = true;
      root.opened = false;
      root.slide = 0;
      root.manual = false;
      root.leaving = false;
      Qt.callLater(() => root.snap = false);
    }
  }

  // The pill this grows out of: its width, height and gap from the screen's
  // right edge. Its top is centred in the bar like every island.
  property real pillWidth: 100

  // Growing rightwards from a pill on the left instead, at pillLeft.
  property bool fromLeft: false
  property real pillLeft: 0

  // What the pill shows, drawn at the same spot while it dissolves.
  property Component face: statusFace

  Component {
    id: statusFace
    StatusFace {
      lit: true
    }
  }
  readonly property real pillHeight: Theme.islandHeight
  readonly property real pillRight: Theme.margin
  readonly property real pillTop: (Theme.barHeight - Theme.islandHeight) / 2

  function toggle() {
    opened ? close() : open();
  }
  function open() {
    root.opened = true;
  }
  function close() {
    root.opened = false;
  }

  // ------------------------------------------------------------- the curves
  readonly property var shapeCurve: [0.34, 1.32, 0.5, 1, 1, 1]
  readonly property int morphMs: 620

  // ----------------------------------------------------------------- window
  anchors {
    top: true
    left: root.fromLeft
    right: !root.fromLeft
  }
  implicitWidth: cardWidth + 240
  implicitHeight: 760
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  WlrLayershell.namespace: "quickshell:panel"
  // Overlay so it reliably sits above the bar's own pill while it grows.
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: !opened ? WlrKeyboardFocus.None : grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  // Only mapped while open or on its way back to the pill.
  visible: opened || shape.visible

  mask: Region {
    x: root.opened ? shape.x : 0
    y: root.opened ? shape.y : 0
    width: root.opened ? root.openWidth : 0
    height: root.opened ? root.openHeight : 0
  }

  readonly property real openWidth: cardWidth
  readonly property real openHeight: 14 + backHeight + body.implicitHeight + 16

  // 0 at the pill, 1 fully open — from the animated height, so anything tied
  // to it moves in exact step with the shape, both ways.
  readonly property real progress: Math.max(0, Math.min(1, (shape.height - pillHeight) / Math.max(1, openHeight - pillHeight)))

  // ---------------------------------------------------------- click outside
  // As Popup.qml: Hyprland refuses a grab for a surface it has not mapped yet,
  // and refuses it silently, so ask until it sticks.
  HyprlandFocusGrab {
    id: grab
    windows: [root]
    onCleared: {
      if (!root.leaving)
        root.close();
    }
  }

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

  // A Connections block, not onOpenedChanged: panels deriving from this
  // define their own handler, which would replace ours.
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

  // ------------------------------------------------------------------ shape
  // The island's soft edge, and a shadow: panels float over the windows.
  Halo {
    target: shape
    shadow: true
  }

  Rectangle {
    id: shape

    // Grows leftwards and down from the pill's top-right corner.
    x: root.fromLeft ? root.pillLeft : root.width - root.pillRight - width
    y: root.pillTop
    width: root.useStart ? root.startW : root.opened ? root.openWidth : root.pillWidth
    height: root.useStart ? root.startH : root.opened ? root.openHeight : root.pillHeight
    radius: Math.min(height / 2, 22)
    clip: true

    color: Theme.island
    border.width: 1
    border.color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.16)

    // Only drawn while open or on the way back; at rest the bar's pill shows.
    visible: root.opened || width > root.pillWidth + 0.5 || height > root.pillHeight + 0.5

    Behavior on width {
      enabled: !root.snap
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }
    Behavior on height {
      enabled: !root.snap
      NumberAnimation {
        duration: root.morphMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.shapeCurve
      }
    }

    // The pill's own face, on the same spot it has on the bar. It dissolves in
    // the first third of the opening and comes back in the last third of the
    // closing, so the pill melts into the panel instead of staying on top.
    Loader {
      sourceComponent: root.face
      anchors.left: root.fromLeft ? parent.left : undefined
      anchors.right: root.fromLeft ? undefined : parent.right
      anchors.leftMargin: Theme.padding
      anchors.rightMargin: Theme.padding
      y: (root.pillHeight - height) / 2
      opacity: 1 - Math.min(1, root.progress * 3)
      scale: 1 - root.progress * 0.15
      visible: opacity > 0.01
    }

    // ‹ Control center
    Rectangle {
      id: backLink
      visible: root.showBack
      x: 10 + root.slide
      y: 10
      width: backRow.implicitWidth + 16
      height: 24
      radius: 12
      color: backArea.containsMouse ? Theme.hover : "transparent"
      opacity: body.opacity
      scale: backArea.pressed ? 0.94 : 1

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: 260
          easing.type: Easing.BezierSpline
          easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1]
        }
      }

      Row {
        id: backRow
        anchors.centerIn: parent
        spacing: 4

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.chevronLeft
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: backArea.containsMouse ? Theme.accent : Theme.fgDim
          // Nudges left on hover, pointing the way.
          transform: Translate {
            x: backArea.containsMouse ? -2 : 0
            Behavior on x {
              NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Control center"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize + 1
          color: backArea.containsMouse ? Theme.fg : Theme.fgDim
        }
      }

      MouseArea {
        id: backArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.back()
      }
    }

    Column {
      id: body
      x: 14 + root.slide
      y: 14 + root.backHeight
      width: root.cardWidth - 28
      spacing: 12

      // Fades out quickly on close so the shrinking shape is clean; while
      // moving between panels the slide drives it instead.
      opacity: root.manual ? root.manualOpacity : root.autoOpacity
    }
  }
}
