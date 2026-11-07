// WallpaperPicker.qml — the centred wallpaper deck.
//
// A fullscreen overlay on one screen: the desktop stays visible behind a light
// scrim (Hyprland blurs it, see the `wallpaper-picker` layer rule), and the
// wallpapers sit in the middle as a fanned deck of slanted cards. The selected
// one is in front at full size; up to three more fan out behind it on each side,
// each step smaller and dimmer, so only a slice of each shows.
//
// - click a side card, scroll, or ←/→ to move along the deck
// - rest the mouse on the front card and it tilts toward the cursor; after half
//   a second the desktop behind faintly previews it
// - click the front card or press Enter to apply; WallpaperReveal.qml then grows
//   it out from the middle of the screen
// - Esc or a click anywhere else closes
//
// The slanted shape is one parallelogram used three ways: the border (a Shape),
// the image mask (a shared, hidden Shape the MultiEffects sample) and the
// highlights drawn over the image.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
  id: root

  // --------------------------------------------------------------- geometry
  readonly property int cardW: 440
  readonly property int cardH: 268
  readonly property real slant: cardW * 0.14   // how far the top edge leans right
  readonly property int rimWidth: 2

  // The deck, by distance from the front card: horizontal offset, scale and
  // opacity. Index 4 is "waiting behind the stack", invisible.
  readonly property var deckX: [0, 225, 300, 360, 400]
  readonly property var deckScale: [1, 0.8, 0.64, 0.5, 0.4]
  readonly property var deckOpacity: [1, 1, 0.8, 0.5, 0]

  // ------------------------------------------------------------------ state
  property bool opened: false
  property int selected: 0

  // Nothing decodes until the first open, so a picker nobody uses costs nothing.
  property bool primed: false

  // Pointer over the front card, normalised to -1..1 on each axis.
  property bool hovering: false
  property real tx: 0
  property real ty: 0
  property bool peeking: false

  readonly property int count: Wallpaper.count
  readonly property string selectedPath: count > 0 ? Wallpaper.files[Math.max(0, Math.min(count - 1, selected))] : ""
  readonly property var selPalette: Wallpaper.paletteFor(selectedPath)

  // What the theme would turn into; tints the border and glow as you browse.
  property color selAccent: Wallpaper.accentFor(selectedPath)
  Behavior on selAccent {
    ColorAnimation {
      duration: 600
    }
  }

  function toggle() {
    opened ? close() : open();
  }

  function open() {
    root.primed = true;
    Wallpaper.rescan();
    if (Wallpaper.currentIndex >= 0)
      root.selected = Wallpaper.currentIndex;
    root.endHover();
    root.opened = true;
  }

  function close() {
    root.endHover();
    root.opened = false;
  }

  function step(delta) {
    if (count === 0)
      return;
    root.endHover();
    root.selected = ((root.selected + delta) % count + count) % count;
  }

  function applySelected() {
    if (selectedPath.length === 0 || Wallpaper.applying)
      return;
    if (selectedPath !== Wallpaper.current)
      Wallpaper.apply(selectedPath);
    root.close();
  }

  function endHover() {
    peekTimer.stop();
    root.hovering = false;
    root.peeking = false;
    root.tx = 0;
    root.ty = 0;
  }

  // The four corners of the parallelogram, pulled in by `i` px on every side
  // (the slanted sides measured square to the edge, so the rim is even).
  function poly(i) {
    const w = cardW, h = cardH, s = slant;
    const dx = i / Math.cos(Math.atan(s / h));
    return [Qt.point(s * (1 - i / h) + dx, i), Qt.point(w - s * i / h - dx, i), Qt.point(w - s * (h - i) / h - dx, h - i), Qt.point(s * i / h + dx, h - i), Qt.point(s * (1 - i / h) + dx, i)];
  }

  readonly property var outerPoly: poly(0)
  readonly property var innerPoly: poly(rimWidth)

  Timer {
    id: peekTimer
    interval: 500
    onTriggered: root.peeking = root.hovering && root.opened && root.selectedPath !== Wallpaper.current
  }

  // ----------------------------------------------------------------- window
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  focusable: true

  WlrLayershell.namespace: "quickshell:wallpaper-picker"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Held up for the length of the exit animation.
  visible: opened || stage.opacity > 0.001

  // ------------------------------------------------------- desktop preview
  // A soft stand-in for the real thing: the thumbnail, blurred, at 60%.
  Image {
    id: peekSource
    anchors.fill: parent
    visible: false
    source: root.primed && root.selectedPath ? "file://" + Wallpaper.thumbFor(root.selectedPath) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  MultiEffect {
    anchors.fill: parent
    source: peekSource
    blurEnabled: true
    blur: 0.35
    blurMax: 32
    opacity: root.peeking && root.opened ? 0.6 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: 700
        easing.type: Easing.InOutQuad
      }
    }
  }

  // The scrim. Light on purpose: you should still see your desktop, just
  // softened. Hyprland's blur is what does the softening.
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0.012, 0.02, 0.035, 0.22)

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
      onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1)
    }
  }

  // ------------------------------------------------------------ shared mask
  // Every card's image is masked by this one hidden layer.
  Item {
    id: innerMask
    width: root.cardW
    height: root.cardH
    visible: false
    layer.enabled: true

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeColor: "transparent"
        fillColor: "white"
        PathPolyline {
          path: root.innerPoly
        }
      }
    }
  }

  // ------------------------------------------------------------------ stage
  Item {
    id: stage

    anchors.fill: parent
    focus: true

    opacity: 0
    scale: 0.9
    property real lift: 40
    transform: Translate {
      y: stage.lift
    }

    states: State {
      name: "open"
      when: root.opened
      PropertyChanges {
        stage.opacity: 1
        stage.scale: 1
        stage.lift: 0
      }
    }

    transitions: [
      Transition {
        to: "open"
        NumberAnimation {
          property: "opacity"
          duration: 500
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          properties: "scale,lift"
          duration: 900
          easing.type: Easing.OutExpo
        }
      },
      Transition {
        from: "open"
        NumberAnimation {
          properties: "opacity,scale,lift"
          duration: 240
          easing.type: Easing.InCubic
        }
      }
    ]

    Keys.onPressed: event => {
      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_H:
        root.step(-1);
        break;
      case Qt.Key_Right:
      case Qt.Key_L:
        root.step(1);
        break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:
        root.applySelected();
        break;
      case Qt.Key_Escape:
        root.close();
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    // ------------------------------------------------------------- the deck
    Item {
      id: deck

      width: root.cardW
      height: root.cardH
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -12

      Repeater {
        model: Wallpaper.files

        delegate: Item {
          id: card

          required property string modelData
          required property int index

          readonly property int d: {
            const n = root.count;
            let v = index - root.selected;
            if (v > n / 2)
              v -= n;
            if (v <= -n / 2)
              v += n;
            return v;
          }
          readonly property int k: Math.min(Math.abs(d), 4)
          readonly property bool isFront: d === 0
          readonly property bool isCurrent: modelData === Wallpaper.current
          readonly property bool tilting: isFront && root.hovering

          // Once a card has been near the front its thumbnail stays loaded.
          property bool everNear: false
          readonly property bool near: Math.abs(d) <= 4
          onNearChanged: if (near)
            everNear = true
          Component.onCompleted: everNear = near

          width: root.cardW
          height: root.cardH
          z: 20 - Math.abs(d)

          x: Math.sign(d) * root.deckX[k]
          scale: root.deckScale[k]
          opacity: root.deckOpacity[k]
          visible: opacity > 0.001

          Behavior on x {
            NumberAnimation {
              duration: 800
              easing.type: Easing.OutQuint
            }
          }
          Behavior on scale {
            NumberAnimation {
              duration: 800
              easing.type: Easing.OutQuint
            }
          }
          Behavior on opacity {
            NumberAnimation {
              duration: 550
              easing.type: Easing.OutCubic
            }
          }

          // The tilt. Quick while following the pointer, slow settling back.
          transform: [
            Rotation {
              origin.x: root.cardW / 2
              origin.y: root.cardH / 2
              axis {
                x: 1
                y: 0
                z: 0
              }
              angle: card.isFront ? -root.ty * 7 : 0
              Behavior on angle {
                NumberAnimation {
                  duration: root.hovering ? 160 : 800
                  easing.type: root.hovering ? Easing.OutCubic : Easing.OutQuint
                }
              }
            },
            Rotation {
              origin.x: root.cardW / 2
              origin.y: root.cardH / 2
              axis {
                x: 0
                y: 1
                z: 0
              }
              angle: card.isFront ? root.tx * 9 : 0
              Behavior on angle {
                NumberAnimation {
                  duration: root.hovering ? 160 : 800
                  easing.type: root.hovering ? Easing.OutCubic : Easing.OutQuint
                }
              }
            }
          ]

          // ---------------------------------------------------------- border
          // Front: white catching into the accent and back. Behind: a faint edge.
          Shape {
            id: rim
            anchors.fill: parent
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              strokeColor: "transparent"
              fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.cardW
                y2: root.cardH
                GradientStop {
                  position: 0
                  color: card.isFront ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.16)
                }
                GradientStop {
                  position: 0.4
                  color: card.isFront ? Qt.rgba(root.selAccent.r, root.selAccent.g, root.selAccent.b, 0.85) : Qt.rgba(1, 1, 1, 0.16)
                }
                GradientStop {
                  position: 0.72
                  color: Qt.rgba(1, 1, 1, card.isFront ? 0.12 : 0.16)
                }
                GradientStop {
                  position: 1
                  color: card.isFront ? Qt.rgba(root.selAccent.r, root.selAccent.g, root.selAccent.b, 0.7) : Qt.rgba(1, 1, 1, 0.16)
                }
              }
              PathPolyline {
                path: root.outerPoly
              }
            }
          }

          // The border, plus the card's shadow — tinted with the accent on the
          // front card, so it glows the colour your theme would become.
          MultiEffect {
            anchors.fill: rim
            source: rim
            shadowEnabled: true
            blurMax: 64
            shadowBlur: 1.0
            shadowScale: card.isFront ? 1.0 : 0.94
            shadowVerticalOffset: card.isFront ? 22 : 8
            shadowColor: card.isFront ? Qt.rgba(root.selAccent.r, root.selAccent.g, root.selAccent.b, 0.5) : Qt.rgba(0, 0, 0, 0.35)
            autoPaddingEnabled: true
          }

          // A spot of light on the border that follows the pointer. Drawn under
          // the image, so it only shows through the rim.
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: card.tilting ? 1 : 0
            Behavior on opacity {
              NumberAnimation {
                duration: 400
              }
            }

            ShapePath {
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                centerX: (root.tx + 1) / 2 * root.cardW
                centerY: (root.ty + 1) / 2 * root.cardH
                focalX: centerX
                focalY: centerY
                centerRadius: root.cardW * 0.42
                focalRadius: 0
                GradientStop {
                  position: 0
                  color: Qt.rgba(1, 1, 1, 0.95)
                }
                GradientStop {
                  position: 1
                  color: Qt.rgba(1, 1, 1, 0)
                }
              }
              PathPolyline {
                path: root.outerPoly
              }
            }
          }

          // ----------------------------------------------------------- image
          Item {
            id: picture
            anchors.fill: parent
            visible: false
            layer.enabled: true
            clip: true

            Image {
              // Slightly oversized so the parallax drift never shows an edge.
              width: parent.width * 1.1
              height: parent.height * 1.1
              x: (parent.width - width) / 2 - (card.tilting ? root.tx * 12 : 0)
              y: (parent.height - height) / 2 - (card.tilting ? root.ty * 8 : 0)
              scale: card.tilting ? 1.05 : 1

              source: root.primed && (card.near || card.everNear) ? "file://" + Wallpaper.thumbFor(card.modelData) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 720

              Behavior on x {
                NumberAnimation {
                  duration: card.tilting ? 220 : 900
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on y {
                NumberAnimation {
                  duration: card.tilting ? 220 : 900
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on scale {
                NumberAnimation {
                  duration: 900
                  easing.type: Easing.OutQuint
                }
              }
            }
          }

          MouseArea {
            id: sideHover
            anchors.fill: parent
            enabled: !card.isFront && card.k <= 3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.endHover();
              root.selected = card.index;
            }
          }

          MultiEffect {
            anchors.fill: parent
            source: picture
            maskEnabled: true
            maskSource: innerMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.6
            // Blur would otherwise pad the output past the card, stretching
            // the mask out of line with the picture.
            autoPaddingEnabled: false

            // Cards behind the front one are pushed back: darker, greyer, softer.
            brightness: card.isFront ? 0 : sideHover.containsMouse ? -0.22 : -0.45
            saturation: card.isFront ? 0.05 : sideHover.containsMouse ? -0.15 : -0.45
            blurEnabled: true
            blurMax: 16
            blur: card.isFront || sideHover.containsMouse ? 0 : 0.12

            Behavior on brightness {
              NumberAnimation {
                duration: 600
              }
            }
            Behavior on saturation {
              NumberAnimation {
                duration: 600
              }
            }
            Behavior on blur {
              NumberAnimation {
                duration: 600
              }
            }
          }

          // ------------------------------------------------------ highlights
          // A glassy diagonal sheen, always on, and a softer pool of light
          // under the pointer while tilting.
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
              strokeColor: "transparent"
              fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.cardW
                y2: root.cardH * 0.6
                GradientStop {
                  position: 0
                  color: Qt.rgba(1, 1, 1, 0.2)
                }
                GradientStop {
                  position: 0.3
                  color: Qt.rgba(1, 1, 1, 0)
                }
                GradientStop {
                  position: 0.7
                  color: Qt.rgba(1, 1, 1, 0)
                }
                GradientStop {
                  position: 1
                  color: Qt.rgba(1, 1, 1, 0.07)
                }
              }
              PathPolyline {
                path: root.innerPoly
              }
            }
          }

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: card.tilting ? 1 : 0
            Behavior on opacity {
              NumberAnimation {
                duration: 400
              }
            }

            ShapePath {
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                centerX: (root.tx + 1) / 2 * root.cardW
                centerY: (root.ty + 1) / 2 * root.cardH
                focalX: centerX
                focalY: centerY
                centerRadius: root.cardW * 0.5
                focalRadius: 0
                GradientStop {
                  position: 0
                  color: Qt.rgba(1, 1, 1, 0.2)
                }
                GradientStop {
                  position: 1
                  color: Qt.rgba(1, 1, 1, 0)
                }
              }
              PathPolyline {
                path: root.innerPoly
              }
            }
          }

          // Marks whichever wallpaper is actually on the desktop.
          Rectangle {
            visible: card.isCurrent
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 76
            anchors.bottomMargin: 16
            width: 9
            height: 9
            radius: 4.5
            color: Theme.accent
            border.width: 2
            border.color: Qt.rgba(0, 0, 0, 0.4)
          }
        }
      }

      // The front card's own input: tilt, peek, and click to apply. Kept
      // outside the cards so the tilt can't feed back into the pointer maths.
      MouseArea {
        anchors.fill: parent
        z: 100
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: mouse => {
          root.hovering = true;
          root.tx = Math.max(-1, Math.min(1, mouse.x / width * 2 - 1));
          root.ty = Math.max(-1, Math.min(1, mouse.y / height * 2 - 1));
          if (!root.peeking && !peekTimer.running)
            peekTimer.start();
        }
        onExited: root.endHover()
        onClicked: root.applySelected()
        onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1)
      }
    }

    // ---------------------------------------------------------- the palette
    // Five dots that drop out from under the card, one after another, each
    // time the front card changes.
    Row {
      anchors.horizontalCenter: deck.horizontalCenter
      anchors.top: deck.bottom
      anchors.topMargin: 28
      spacing: 10

      Repeater {
        model: 5

        delegate: Rectangle {
          id: dot

          required property int index

          property real drop: -16
          property real grow: 0.4

          width: 14
          height: 14
          radius: 7
          opacity: 0
          border.width: 1.5
          border.color: Qt.rgba(1, 1, 1, 0.22)

          scale: grow * (dotHover.containsMouse ? 1.35 : 1)
          transform: Translate {
            y: dot.drop
          }

          Behavior on scale {
            NumberAnimation {
              duration: 220
              easing.type: Easing.OutBack
            }
          }

          SequentialAnimation {
            id: land

            NumberAnimation {
              target: dot
              property: "opacity"
              to: 0
              duration: 90
            }
            ScriptAction {
              script: {
                dot.color = root.selPalette[dot.index] ?? "transparent";
                dot.drop = -16;
                dot.grow = 0.4;
              }
            }
            PauseAnimation {
              duration: 120 + dot.index * 55
            }
            ParallelAnimation {
              NumberAnimation {
                target: dot
                property: "opacity"
                to: dot.index < root.selPalette.length ? 1 : 0
                duration: 400
              }
              NumberAnimation {
                target: dot
                property: "drop"
                to: 0
                duration: 650
                easing.type: Easing.OutBack
              }
              NumberAnimation {
                target: dot
                property: "grow"
                to: 1
                duration: 650
                easing.type: Easing.OutBack
              }
            }
          }

          Connections {
            target: root
            function onSelPaletteChanged() {
              land.restart();
            }
            function onOpenedChanged() {
              if (root.opened)
                land.restart();
            }
          }

          MouseArea {
            id: dotHover
            anchors.fill: parent
            hoverEnabled: true
          }
        }
      }
    }

    // Shown only until the first scan lands.
    Text {
      anchors.centerIn: deck
      visible: root.count === 0
      text: Wallpaper.scanning ? "Preparing previews…" : "No images in " + Wallpaper.folder
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: "white"
    }
  }
}
