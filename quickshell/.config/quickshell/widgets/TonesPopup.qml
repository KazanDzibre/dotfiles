// TonesPopup.qml — pick a healing frequency, or stop the one that's playing.
//
// Two columns of tiles, ordered by pitch so the grid reads as a scale. The tile
// that is sounding is filled with the accent; clicking it again is the stop.
import QtQuick
import qs

Popup {
  id: root

  readonly property int columns: 2
  readonly property int tileSpacing: 6
  readonly property int tileWidth: Math.floor((cardWidth - 28 - tileSpacing * (columns - 1)) / columns)
  readonly property int tileHeight: 40

  cardWidth: 300
  align: "center"

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 20

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "FREQUENCIES"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Tones.active ? Tones.playing + " Hz" : "silent"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Tones.active ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }
  }

  // ------------------------------------------------------------------- tiles
  Grid {
    width: parent.width
    columns: root.columns
    spacing: root.tileSpacing

    Repeater {
      model: Tones.catalogue

      delegate: Rectangle {
        id: tile

        required property var modelData

        readonly property bool sounding: Tones.playing === modelData.hz

        width: root.tileWidth
        height: root.tileHeight
        radius: 10

        color: sounding ? Theme.accentSoft : hover.containsMouse ? Theme.hover : Theme.raised

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        scale: hover.containsMouse ? 1.04 : 1.0

        Behavior on scale {
          NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutBack
          }
        }

        Column {
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          Text {
            text: tile.modelData.hz + " Hz"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            color: tile.sounding ? Theme.accent : Theme.fg

            Behavior on color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }
          }

          Text {
            width: parent.width
            text: tile.modelData.name
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize - 1
            color: Theme.fgDim
          }
        }

        MouseArea {
          id: hover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Tones.toggle(tile.modelData.hz)
        }
      }
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
  }

  // ------------------------------------------------------------------ volume
  Row {
    width: parent.width
    spacing: 10

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      horizontalAlignment: Text.AlignHCenter
      text: Tones.volume < 0.02 ? Icons.volMute : Tones.volume < 0.5 ? Icons.volLow : Icons.volMed
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize + 2
      color: Tones.active ? Theme.accent : Theme.fgDim

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Slider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 30
      value: Tones.volume
      onMoved: v => Tones.setVolume(v)
    }
  }

  // ------------------------------------------------------------------- stop
  // Only while something is sounding — an always-visible stop that does nothing
  // most of the time is just noise in a small card.
  Rectangle {
    width: parent.width
    height: Tones.active ? 30 : 0
    radius: 9
    clip: true
    visible: height > 0

    color: stopHover.containsMouse ? Theme.hover : Theme.raised

    Behavior on height {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.OutCubic
      }
    }
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
        text: Icons.stop
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: stopHover.containsMouse ? Theme.crit : Theme.fgDim

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Tones.active ? "Stop " + Tones.nameFor(Tones.playing) : "Stop"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: stopHover.containsMouse ? Theme.fg : Theme.fgDim

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }
      }
    }

    MouseArea {
      id: stopHover

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Tones.stop()
    }
  }
}
