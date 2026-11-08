// WindowSwitcher.qml — the window-title pill, opened out into every open
// window. Same morph as the control center, growing rightwards from the left
// of the bar. Click a window to go to it, × closes it.
//
// Thumbnails refresh about once a second rather than every frame, so this
// stays smooth with a lot of windows open.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

MorphPanel {
  id: root

  cardWidth: 560
  fromLeft: true
  contentSpacing: 10

  readonly property int columns: 3
  readonly property int tileGap: 10
  readonly property real tileWidth: (cardWidth - 28 - tileGap * (columns - 1)) / columns

  readonly property var windows: Array.from(ToplevelManager.toplevels.values)

  // The last window closing leaves nothing to show.
  onWindowsChanged: {
    if (windows.length === 0 && opened)
      close();
  }

  Item {
    width: parent.width
    height: 22

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Open windows"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Theme.fg
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.windows.length
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fgDim
    }
  }

  Grid {
    columns: root.columns
    spacing: root.tileGap

    Repeater {
      model: root.windows

      delegate: Rectangle {
        id: tile

        required property var modelData
        required property int index

        readonly property bool isActive: modelData === ToplevelManager.activeToplevel
        readonly property string iconUrl: Icons.themeIconFor(modelData.appId)

        property bool arrived: false

        width: root.tileWidth
        height: 136
        radius: 14
        color: tileArea.containsMouse ? Theme.hover : Theme.raised
        border.width: isActive ? 2 : 0
        border.color: Theme.accent

        // One after another, while the panel is still opening.
        opacity: arrived ? 1 : 0
        transform: Translate {
          y: tile.arrived ? 0 : 14
          Behavior on y {
            NumberAnimation {
              duration: 560
              easing.type: Easing.BezierSpline
              easing.bezierCurve: [0.34, 1.4, 0.5, 1, 1, 1]
            }
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 300
          }
        }
        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Timer {
          running: root.opened
          interval: 90 + tile.index * 45
          onTriggered: tile.arrived = true
        }

        Connections {
          target: root
          function onOpenedChanged() {
            if (!root.opened)
              tile.arrived = false;
          }
        }

        MouseArea {
          id: tileArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            tile.modelData.activate();
            root.close();
          }
        }

        ClippingRectangle {
          x: 7
          y: 7
          width: parent.width - 14
          height: 92
          radius: 9
          color: Theme.base

          IconImage {
            anchors.centerIn: parent
            visible: !capture.hasContent
            implicitSize: 32
            source: tile.iconUrl
          }

          ScreencopyView {
            id: capture

            readonly property real aspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6

            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * aspect)
            height: width / aspect
            captureSource: root.opened ? tile.modelData : null
            live: false
            constraintSize: Qt.size(Math.round(root.tileWidth * 2), 184)

            onCaptureSourceChanged: {
              if (captureSource)
                captureFrame();
            }
          }

          Timer {
            running: root.opened
            repeat: true
            interval: 1000
            onTriggered: capture.captureFrame()
          }
        }

        Row {
          x: 10
          y: 108
          spacing: 7

          IconImage {
            anchors.verticalCenter: parent.verticalCenter
            visible: tile.iconUrl !== ""
            source: tile.iconUrl
            implicitSize: 15
            asynchronous: true
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - 42
            text: tile.modelData.title
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize + 1
            color: Theme.fg
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 12
          width: 22
          height: 22
          radius: 11
          opacity: tileArea.containsMouse || closeArea.containsMouse ? 1 : 0
          color: closeArea.containsMouse ? Theme.crit : Qt.rgba(0.02, 0.02, 0.02, 0.72)

          Behavior on opacity {
            NumberAnimation {
              duration: Theme.animFast
            }
          }

          Text {
            anchors.centerIn: parent
            text: Icons.close
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize + 1
            color: "white"
          }

          MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.modelData.close()
          }
        }
      }
    }
  }
}
