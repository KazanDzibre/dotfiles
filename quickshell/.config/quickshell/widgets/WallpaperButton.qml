// WallpaperButton.qml — opens the wallpaper carousel.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.wallpaper
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    // A slow pulse while waypaper is working; it takes a moment to hand the
    // image to hyprpaper and re-run pywal.
    SequentialAnimation on opacity {
      running: Wallpaper.applying
      loops: Animation.Infinite

      NumberAnimation {
        to: 0.4
        duration: 500
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1.0
        duration: 500
        easing.type: Easing.InOutSine
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  WallpaperPopup {
    id: popup
    anchorItem: root
  }
}
