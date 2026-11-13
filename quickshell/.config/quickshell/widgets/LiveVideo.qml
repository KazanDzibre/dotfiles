// LiveVideo.qml — the video behind a video wallpaper, played muted and looped.
//
// Loaded by ParallaxWallpaper.qml only while a video wallpaper is current and
// the machine is on mains power. It fills its parent, so it slides with the
// parallax exactly like the still image it sits on, and it fades in once the
// first frame is up so the hand-over from the still is invisible.
import QtQuick
import QtMultimedia
import qs

Item {
  id: root

  opacity: player.position > 0 ? 1 : 0

  Behavior on opacity {
    NumberAnimation {
      duration: 400
    }
  }

  MediaPlayer {
    id: player
    source: "file://" + Wallpaper.liveVideo
    loops: MediaPlayer.Infinite
    videoOutput: output
    Component.onCompleted: play()
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }
}
