// MediaPopup.qml — the full media controller.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

Popup {
  id: root

  cardWidth: 324
  align: "center"

  // Only poll MPRIS position while the panel is actually on screen.
  onOpenedChanged: Media.trackPosition = opened

  readonly property var player: Media.active

  function cycleLoop() {
    if (!player || !player.loopSupported)
      return;
    if (player.loopState === MprisLoopState.None)
      player.loopState = MprisLoopState.Playlist;
    else if (player.loopState === MprisLoopState.Playlist)
      player.loopState = MprisLoopState.Track;
    else
      player.loopState = MprisLoopState.None;
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 18

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "NOW PLAYING"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 110
      horizontalAlignment: Text.AlignRight
      text: root.player ? root.player.identity : ""
      elide: Text.ElideRight
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  // ------------------------------------------------------------- art + track
  Row {
    width: parent.width
    spacing: 12
    visible: Media.hasPlayer

    Rectangle {
      id: artFrame

      width: 62
      height: 62
      radius: 10
      color: Theme.raised
      clip: true

      Image {
        id: art
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 128
        visible: status === Image.Ready
      }

      // Players without art, or art that failed to load.
      Text {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: Icons.album
        font.family: Theme.fontFamily
        font.pixelSize: 26
        color: Theme.fgDim
      }
    }

    Column {
      width: parent.width - 74
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Text {
        width: parent.width
        text: Media.title.length > 0 ? Media.title : "Nothing playing"
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        color: Theme.fg
      }

      Text {
        width: parent.width
        visible: Media.artist.length > 0
        text: Media.artist
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize + 1
        color: Theme.accent
      }

      Text {
        width: parent.width
        visible: Media.album.length > 0
        text: Media.album
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }
    }
  }

  // ---------------------------------------------------------- wide analyser
  Item {
    width: parent.width
    height: 26
    visible: Media.hasPlayer

    Spectrum {
      anchors.centerIn: parent
      bars: 28
      barWidth: 4
      barSpacing: 4
      minHeight: 3
      maxHeight: 26
    }
  }

  // ---------------------------------------------------------------- progress
  Column {
    width: parent.width
    spacing: 4
    visible: Media.hasPlayer && Media.length > 0

    Slider {
      width: parent.width
      enabled: Media.seekable
      value: Media.length > 0 ? Media.position / Media.length : 0
      onMoved: v => {
        if (Media.seekable && root.player)
          root.player.position = v * Media.length;
      }
    }

    Item {
      width: parent.width
      height: 12

      Text {
        anchors.left: parent.left
        text: Media.formatTime(Media.position)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }

      Text {
        anchors.right: parent.right
        text: Media.formatTime(Media.length)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }
    }
  }

  // ---------------------------------------------------------------- controls
  Item {
    width: parent.width
    height: 40
    visible: Media.hasPlayer

    // Shuffle, left of centre.
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: root.player && root.player.shuffleSupported
      width: 26
      height: 26
      radius: 13
      color: shuffleHover.containsMouse ? Theme.hover : "transparent"

      Text {
        anchors.centerIn: parent
        text: root.player && root.player.shuffle ? Icons.shuffle : Icons.shuffleOff
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: root.player && root.player.shuffle ? Theme.accent : Theme.fgDim
      }

      MouseArea {
        id: shuffleHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.player)
            root.player.shuffle = !root.player.shuffle;
        }
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 10

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: prevHover.containsMouse ? Theme.hover : Theme.raised
        opacity: root.player && root.player.canGoPrevious ? 1 : 0.4

        Text {
          anchors.centerIn: parent
          text: Icons.prev
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.fg
        }

        MouseArea {
          id: prevHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.player)
              root.player.previous();
          }
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 19
        color: playHover.containsMouse ? Theme.accent : Theme.accentSoft

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.centerIn: parent
          text: Media.playing ? Icons.pause : Icons.play
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize + 6
          color: playHover.containsMouse ? Theme.base : Theme.accent
        }

        MouseArea {
          id: playHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.player)
              root.player.togglePlaying();
          }
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: nextHover.containsMouse ? Theme.hover : Theme.raised
        opacity: root.player && root.player.canGoNext ? 1 : 0.4

        Text {
          anchors.centerIn: parent
          text: Icons.next
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.fg
        }

        MouseArea {
          id: nextHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.player)
              root.player.next();
          }
        }
      }
    }

    // Loop, right of centre.
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: root.player && root.player.loopSupported
      width: 26
      height: 26
      radius: 13
      color: loopHover.containsMouse ? Theme.hover : "transparent"

      Text {
        anchors.centerIn: parent
        text: {
          if (!root.player)
            return Icons.repeatOff;
          if (root.player.loopState === MprisLoopState.Track)
            return Icons.repeatOne;
          if (root.player.loopState === MprisLoopState.Playlist)
            return Icons.repeatAll;
          return Icons.repeatOff;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: root.player && root.player.loopState !== MprisLoopState.None ? Theme.accent : Theme.fgDim
      }

      MouseArea {
        id: loopHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cycleLoop()
      }
    }
  }

  // ----------------------------------------------------------- player picker
  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
    visible: Media.players.length > 1
  }

  Row {
    width: parent.width
    spacing: 6
    visible: Media.players.length > 1

    Repeater {
      model: Media.players

      delegate: Rectangle {
        id: playerChip

        required property var modelData
        readonly property bool current: Media.active === modelData

        height: 22
        width: Math.min(96, chipLabel.implicitWidth + 18)
        radius: 11
        color: current ? Theme.accentSoft : chipHover.containsMouse ? Theme.hover : Theme.raised

        Text {
          id: chipLabel
          anchors.centerIn: parent
          width: parent.width - 14
          horizontalAlignment: Text.AlignHCenter
          text: playerChip.modelData.identity
          elide: Text.ElideRight
          font.family: Theme.fontFamily
          font.pixelSize: Theme.smallSize
          color: playerChip.current ? Theme.accent : Theme.fgDim
        }

        MouseArea {
          id: chipHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Media.select(playerChip.modelData)
        }
      }
    }
  }

  // ------------------------------------------------------------- empty state
  Text {
    width: parent.width
    visible: !Media.hasPlayer
    text: "No media player running."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }
}
