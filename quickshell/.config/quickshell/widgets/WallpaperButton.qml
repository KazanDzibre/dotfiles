// WallpaperButton.qml — opens the wallpaper deck on this bar's screen.
import QtQuick
import qs

Item {
  id: root

  // The picker is fullscreen, so it needs to know which screen it belongs to.
  property var barScreen

  implicitWidth: 18
  implicitHeight: 18

  Text {
    anchors.centerIn: parent
    text: Icons.wallpaper
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: picker.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

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
    onClicked: picker.toggle()
  }

  WallpaperPicker {
    id: picker
    screen: root.barScreen
  }

  Connections {
    target: Wallpaper

    function onPickerToggleRequested(screenName) {
      if (root.barScreen && root.barScreen.name === screenName)
        picker.toggle();
    }
  }
}
