// VolumePopup.qml — visual audio control.
//
// Output slider with a live peak meter, microphone slider, and a picker for
// which device output should go to.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

Popup {
  id: root

  cardWidth: 310
  align: "right"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sinkAudio: sink ? sink.audio : null
  readonly property var sourceAudio: source ? source.audio : null

  // Every sink that is a real device rather than an application stream.
  readonly property var sinks: Pipewire.ready ? Array.from(Pipewire.nodes.values).filter(n => n.isSink && !n.isStream) : []

  function nodeLabel(node) {
    if (!node)
      return "No device";
    return node.description || node.nickname || node.name || "Unknown";
  }

  PwObjectTracker {
    objects: {
      const list = root.sinks.slice();
      if (root.source)
        list.push(root.source);
      return list;
    }
  }

  // Only meter while the popup is actually on screen.
  PwNodePeakMonitor {
    id: peakMonitor
    node: root.sink
    enabled: root.visible
  }

  // ------------------------------------------------------------------ output
  Text {
    text: "OUTPUT"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    font.bold: true
    font.letterSpacing: 1
    color: Theme.fgDim
  }

  Item {
    width: parent.width
    height: 22

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 46
      text: root.nodeLabel(root.sink)
      elide: Text.ElideRight
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fg
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) + "%" : "--"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Theme.accent
    }
  }

  Row {
    width: parent.width
    spacing: 10

    // Mute toggle
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 30
      height: 30
      radius: 15
      color: root.sinkAudio && root.sinkAudio.muted ? Theme.crit : muteHover.containsMouse ? Theme.hover : Theme.raised

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.sinkAudio && root.sinkAudio.muted ? Icons.volMute : Icons.volHigh
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: root.sinkAudio && root.sinkAudio.muted ? Theme.base : Theme.fg
      }

      MouseArea {
        id: muteHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.sinkAudio)
            root.sinkAudio.muted = !root.sinkAudio.muted;
        }
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 40
      spacing: 5

      Slider {
        width: parent.width
        value: root.sinkAudio ? root.sinkAudio.volume : 0
        enabled: root.sinkAudio !== null && !root.sinkAudio.muted
        onMoved: v => {
          if (root.sinkAudio)
            root.sinkAudio.volume = v;
        }
      }

      // Live level meter — shows what is actually coming out right now.
      Rectangle {
        width: parent.width
        height: 3
        radius: 1.5
        color: Theme.raised

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, peakMonitor.peak))
          height: parent.height
          radius: parent.radius
          color: Theme.accent
          opacity: 0.7

          Behavior on width {
            NumberAnimation {
              duration: 70
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- microphone
  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
  }

  Text {
    text: "MICROPHONE"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    font.bold: true
    font.letterSpacing: 1
    color: Theme.fgDim
  }

  Row {
    width: parent.width
    spacing: 10

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 30
      height: 30
      radius: 15
      color: root.sourceAudio && root.sourceAudio.muted ? Theme.crit : micHover.containsMouse ? Theme.hover : Theme.raised

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      Text {
        anchors.centerIn: parent
        text: root.sourceAudio && root.sourceAudio.muted ? Icons.micOff : Icons.mic
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: root.sourceAudio && root.sourceAudio.muted ? Theme.base : Theme.fg
      }

      MouseArea {
        id: micHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.sourceAudio)
            root.sourceAudio.muted = !root.sourceAudio.muted;
        }
      }
    }

    Slider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 40
      value: root.sourceAudio ? root.sourceAudio.volume : 0
      enabled: root.sourceAudio !== null && !root.sourceAudio.muted
      onMoved: v => {
        if (root.sourceAudio)
          root.sourceAudio.volume = v;
      }
    }
  }

  // ----------------------------------------------------------- device picker
  Rectangle {
    width: parent.width
    height: 1
    color: Theme.border
    visible: root.sinks.length > 1
  }

  Text {
    text: "PLAY THROUGH"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    font.bold: true
    font.letterSpacing: 1
    color: Theme.fgDim
    visible: root.sinks.length > 1
  }

  Column {
    width: parent.width
    spacing: 3
    visible: root.sinks.length > 1

    Repeater {
      model: root.sinks

      delegate: Rectangle {
        id: deviceRow

        required property var modelData
        readonly property bool current: root.sink && modelData.id === root.sink.id

        width: parent.width
        height: 28
        radius: 8
        color: current ? Theme.accentSoft : deviceHover.containsMouse ? Theme.hover : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 9
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 34
          text: root.nodeLabel(deviceRow.modelData)
          elide: Text.ElideRight
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: deviceRow.current ? Theme.accent : Theme.fg
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 9
          anchors.verticalCenter: parent.verticalCenter
          visible: deviceRow.current
          text: Icons.check
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.accent
        }

        MouseArea {
          id: deviceHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Pipewire.preferredDefaultAudioSink = deviceRow.modelData
        }
      }
    }
  }
}
