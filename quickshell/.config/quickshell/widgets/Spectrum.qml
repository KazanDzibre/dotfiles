// Spectrum.qml — a Winamp-style analyser driven by real audio.
//
// PwAudioSpectrum runs an FFT over the sink's monitor stream, so these bars are
// the actual frequency content of whatever is playing, not a canned animation.
// It is only enabled while something is playing — an idle FFT is pure waste.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

Item {
  id: root

  property int bars: 5
  property int barWidth: 3
  property int barSpacing: 2
  property int minHeight: 3
  property int maxHeight: 15
  property bool active: Media.playing
  property color color: Theme.accent

  implicitWidth: bars * barWidth + (bars - 1) * barSpacing
  implicitHeight: maxHeight

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  PwAudioSpectrum {
    id: spectrum

    node: Pipewire.defaultAudioSink
    enabled: root.active
    barCount: root.bars
    frameRate: 30
    smoothing: true
  }

  Row {
    anchors.centerIn: parent
    spacing: root.barSpacing

    Repeater {
      model: root.bars

      delegate: Rectangle {
        required property int index

        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        radius: root.barWidth / 2
        color: root.color
        opacity: root.active ? 1.0 : 0.45

        height: {
          if (!root.active)
            return root.minHeight;
          const values = spectrum.values;
          const level = values && values.length > index ? values[index] : 0;
          return root.minHeight + Math.max(0, Math.min(1, level)) * (root.maxHeight - root.minHeight);
        }

        // Short enough to still feel reactive at 30fps, long enough that the
        // bars glide instead of strobing.
        Behavior on height {
          NumberAnimation {
            duration: 90
            easing.type: Easing.OutQuad
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animFast
          }
        }
      }
    }
  }
}
