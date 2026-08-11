// MediaIsland.qml — now playing, via MPRIS.
//
// Left click toggles play/pause, middle skips forward, right skips back, and
// scrolling anywhere on it changes track.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

Item {
  id: root

  // Prefer whatever is actually playing; fall back to the first player that
  // exists so a paused Spotify still shows its track.
  readonly property var player: {
    const players = Array.from(Mpris.players.values);
    if (players.length === 0)
      return null;
    return players.find(p => p.isPlaying) ?? players[0];
  }

  readonly property bool hasPlayer: player !== null
  readonly property bool playing: hasPlayer && player.isPlaying

  readonly property string label: {
    if (!player)
      return "";
    const title = player.trackTitle ?? "";
    const artist = player.trackArtist ?? "";
    if (title && artist)
      return artist + "  ·  " + title;
    return title || artist || player.identity || "";
  }

  property int maxWidth: 190

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8

    // ------------------------------------------------- animated equaliser
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: 13
      height: 14

      Row {
        anchors.centerIn: parent
        spacing: 2
        visible: root.playing

        Repeater {
          model: 3

          delegate: Rectangle {
            required property int index

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 4
            radius: 1.5
            color: Theme.accent

            // Slightly different periods per bar so they never march in step.
            SequentialAnimation on height {
              running: root.playing
              loops: Animation.Infinite

              NumberAnimation {
                to: 13
                duration: 300 + index * 80
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                to: 4
                duration: 260 + index * 60
                easing.type: Easing.InOutSine
              }
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !root.playing
        text: Icons.pause
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: Theme.fgDim
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: root.playing ? Theme.fg : Theme.fgDim
      elide: Text.ElideRight
      width: Math.min(implicitWidth, root.maxWidth)
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: event => {
      if (!root.player)
        return;
      if (event.button === Qt.LeftButton)
        root.player.togglePlaying();
      else if (event.button === Qt.MiddleButton)
        root.player.next();
      else
        root.player.previous();
    }
  }

  WheelHandler {
    onWheel: event => {
      if (!root.player)
        return;
      if (event.angleDelta.y > 0)
        root.player.previous();
      else
        root.player.next();
    }
  }
}
