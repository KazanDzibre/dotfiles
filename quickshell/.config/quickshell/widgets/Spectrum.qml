// Spectrum.qml — a Winamp-style analyser driven by real audio.
//
// The bars are the actual frequency content of whatever is playing, not a
// canned animation. cava does the FFT and prints one line per frame; this only
// parses it.
//
// Why cava and not Quickshell's own Pipewire service: there is no spectrum type
// in it. `Quickshell.Services.Pipewire` exposes nodes, links and volumes, but
// nothing that runs an FFT — an earlier version of this file called a
// `PwAudioSpectrum`, which does not exist in Quickshell (checked against 0.3.1
// and master), so the whole shell failed to load with "PwAudioSpectrum is not a
// type". cava is also what the eww bar this replaces used, via the same raw
// ascii output.
//
// cava is an optional dependency on purpose. If it is not installed, or it
// exits, `values` simply stays empty and the bars rest at minHeight — the bar
// still loads. Never reintroduce a hard dependency on a type that has to exist
// at load time for the analyser to work.
import QtQuick
import Quickshell.Io
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

  // One normalised 0..1 level per bar, newest frame only.
  property var values: []

  implicitWidth: bars * barWidth + (bars - 1) * barSpacing
  implicitHeight: maxHeight

  // Only while something is playing — an idle FFT is pure waste, and cava keeps
  // a capture stream open on the sink monitor for as long as it runs.
  Process {
    id: cava

    running: root.active
    // cava is configured through a file, so the config is generated on stdin.
    // ascii_max_range=100 makes every field a plain 0..100 integer, which is
    // cheaper to parse than the block-drawing characters the eww bar used.
    command: ["sh", "-c", "printf '[general]\\nframerate=30\\nbars=%d\\nautosens=1\\n[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100\\n' " + root.bars + " | exec cava -p /dev/stdin"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.ingest(line)
    }

    // Covers both "cava is not installed" and "cava died". Clearing the values
    // drops the bars to rest instead of freezing them on the last frame.
    onExited: root.values = []
  }

  // Bars rest when playback stops, rather than holding the last frame.
  onActiveChanged: if (!active) root.values = []

  function ingest(line) {
    // A frame is "12;40;3;0;88;" — trailing separator included, so the split
    // leaves an empty last field.
    const fields = line.trim().split(";").filter(f => f.length > 0);
    if (fields.length === 0)
      return;

    const levels = [];
    for (const field of fields) {
      const n = Number(field);
      if (isNaN(n))
        return;                      // a malformed frame is dropped whole
      levels.push(Math.max(0, Math.min(1, n / 100)));
    }
    root.values = levels;
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
          const values = root.values;
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
      }
    }
  }
}
