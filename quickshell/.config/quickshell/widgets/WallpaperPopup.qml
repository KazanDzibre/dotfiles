// WallpaperPopup.qml — browse wallpapers as a carousel, then apply one.
//
// Browsing only moves the selection; nothing is applied until you ask, because
// every apply re-runs pywal and re-themes the shell.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  cardWidth: 428
  align: "center"

  readonly property int stripItemWidth: 84
  readonly property int stripItemHeight: 52
  readonly property int stripSpacing: 6

  property int selected: 0

  // Wallpapers are multi-megabyte 2560x1600 PNGs. Decoding 21 of them at shell
  // startup would cost a visible chunk of CPU for a panel that may never be
  // opened, so nothing loads until the first time it is.
  property bool primed: false

  readonly property string selectedPath: {
    if (Wallpaper.count === 0)
      return "";
    const i = Math.max(0, Math.min(Wallpaper.count - 1, selected));
    return Wallpaper.files[i];
  }

  readonly property bool selectedIsCurrent: selectedPath.length > 0 && selectedPath === Wallpaper.current

  onVisibleChanged: {
    if (visible) {
      root.primed = true;
      Wallpaper.rescan();
      if (Wallpaper.currentIndex >= 0)
        root.selected = Wallpaper.currentIndex;
    }
  }

  function step(delta) {
    const n = Wallpaper.count;
    if (n === 0)
      return;
    root.selected = ((root.selected + delta) % n + n) % n;
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 22

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "WALLPAPER"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Wallpaper.count > 0 ? (root.selected + 1) + " / " + Wallpaper.count : "no images"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 11
        color: shuffleHover.containsMouse ? Theme.hover : "transparent"

        Text {
          anchors.centerIn: parent
          text: Icons.shuffle
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.fgDim
        }

        MouseArea {
          id: shuffleHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Wallpaper.random();
            root.close();
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- big preview
  Rectangle {
    width: parent.width
    height: 220
    radius: 12
    color: Theme.raised
    clip: true

    Image {
      id: preview

      anchors.fill: parent
      source: root.primed && root.selectedPath ? "file://" + Wallpaper.thumbFor(root.selectedPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 720
      opacity: status === Image.Ready ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: 200
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: preview.status !== Image.Ready
      text: Wallpaper.scanning && Wallpaper.count === 0 ? "Preparing previews…" : Wallpaper.count === 0 ? "No images in " + Wallpaper.folder : "Loading…"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fgDim
    }

    // "this one is already on your desktop"
    Rectangle {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 8
      visible: root.selectedIsCurrent
      width: currentRow.implicitWidth + 16
      height: 22
      radius: 11
      color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.75)

      Row {
        id: currentRow
        anchors.centerIn: parent
        spacing: 5

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Icons.check
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize + 2
          color: Theme.accent
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "current"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          color: Theme.fg
        }
      }
    }

    // Carousel arrows, overlaid on the preview edges.
    Repeater {
      model: [
        {
          glyph: Icons.chevronLeft,
          delta: -1,
          left: true
        },
        {
          glyph: Icons.chevronRight,
          delta: 1,
          left: false
        }
      ]

      delegate: Rectangle {
        id: arrow

        required property var modelData

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: modelData.left ? parent.left : undefined
        anchors.right: modelData.left ? undefined : parent.right
        anchors.margins: 8

        width: 30
        height: 30
        radius: 15
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, arrowHover.containsMouse ? 0.9 : 0.6)
        visible: Wallpaper.count > 1

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.centerIn: parent
          text: arrow.modelData.glyph
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize + 2
          color: Theme.fg
        }

        MouseArea {
          id: arrowHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.step(arrow.modelData.delta)
        }
      }
    }

    WheelHandler {
      onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }
  }

  // -------------------------------------------------------------- file name
  Text {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: root.selectedPath ? Wallpaper.baseName(root.selectedPath) : ""
    elide: Text.ElideMiddle
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.fgDim
  }

  // -------------------------------------------------------------- film strip
  Item {
    width: parent.width
    height: root.stripItemHeight + 6
    clip: true

    Row {
      id: strip

      anchors.verticalCenter: parent.verticalCenter
      spacing: root.stripSpacing

      // Slide the strip so the selected thumbnail sits in the middle.
      x: -(root.selected * (root.stripItemWidth + root.stripSpacing)) + (parent.width - root.stripItemWidth) / 2

      Behavior on x {
        NumberAnimation {
          duration: Theme.animSlow
          easing.type: Easing.OutQuint
        }
      }

      Repeater {
        model: Wallpaper.files

        delegate: Rectangle {
          id: thumb

          required property var modelData
          required property int index

          readonly property bool isSelected: index === root.selected

          width: root.stripItemWidth
          height: root.stripItemHeight
          radius: 7
          color: Theme.raised
          clip: true

          border.width: isSelected ? 2 : 0
          border.color: Theme.accent

          scale: isSelected ? 1.0 : 0.86
          opacity: isSelected ? 1.0 : 0.45

          Behavior on scale {
            NumberAnimation {
              duration: Theme.animSlow
              easing.type: Easing.OutQuint
            }
          }
          Behavior on opacity {
            NumberAnimation {
              duration: Theme.animSlow
            }
          }

          Image {
            anchors.fill: parent
            anchors.margins: thumb.isSelected ? 2 : 0
            source: root.primed ? "file://" + Wallpaper.thumbFor(thumb.modelData) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 180
          }

          // Dot marking whichever one is actually applied.
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 4
            visible: thumb.modelData === Wallpaper.current
            width: 8
            height: 8
            radius: 4
            color: Theme.accent
            border.width: 1
            border.color: Theme.base
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.selected = thumb.index
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------ action
  Rectangle {
    id: applyButton

    width: parent.width
    height: 32
    radius: 9

    readonly property bool actionable: !root.selectedIsCurrent && root.selectedPath.length > 0 && !Wallpaper.applying
    readonly property color contentColor: !actionable ? Theme.fgDim : applyHover.containsMouse ? Theme.base : Theme.accent

    color: !actionable ? Theme.raised : applyHover.containsMouse ? Theme.accent : Theme.accentSoft

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 7

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.wallpaper
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: applyButton.contentColor
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Wallpaper.applying ? "Applying…" : root.selectedIsCurrent ? "Already your wallpaper" : "Set wallpaper"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        color: applyButton.contentColor
      }
    }

    MouseArea {
      id: applyHover
      anchors.fill: parent
      hoverEnabled: true
      enabled: applyButton.actionable
      cursorShape: Qt.PointingHandCursor
      onClicked: Wallpaper.apply(root.selectedPath)
    }
  }
}
