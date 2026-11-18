// LiveVideo.qml — the video behind a video wallpaper, played muted and looped.
//
// Loaded by ParallaxWallpaper.qml only while a video wallpaper is current and
// the machine is on mains power, and paused while a window hides it. It fills its parent, so it slides with the
// parallax exactly like the still image it sits on, and it fades in once the
// first frame is up so the hand-over from the still is invisible.
import QtQuick
import QtMultimedia
import qs

Item {
  id: root

  // Set by ParallaxWallpaper: true while a window covers this screen's
  // wallpaper, when there is nothing to gain from decoding.
  property bool paused: false

  onPausedChanged: {
    if (paused)
      player.pause();
    else
      player.play();
  }

  opacity: player.position > 0 ? 1 : 0

  Behavior on opacity {
    NumberAnimation {
      duration: 400
    }
  }

  MediaPlayer {
    id: player
    // The lighter battery copy, or the full one: Wallpaper picks by power.
    // If the battery copy isn't made yet, the full one plays instead.
    property bool useFull: false
    source: "file://" + (useFull ? Wallpaper.framesDir + "/" + Wallpaper.baseName(Wallpaper.liveVideo) + ".live.mp4" : Wallpaper.liveFileFor(Wallpaper.liveVideo))
    loops: MediaPlayer.Infinite
    videoOutput: output
    Component.onCompleted: play()

    // Plugging in or unplugging swaps the file, which stops the player.
    onSourceChanged: {
      if (!root.paused)
        play();
    }
    onErrorOccurred: {
      if (!useFull)
        useFull = true;
    }
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }
}
