// TonesButton.qml — opens the healing frequency picker.
//
// While a tone is sounding the glyph stays lit and breathes, so the bar makes
// it obvious where the hum is coming from. Right click stops it without opening
// anything, because reaching for silence shouldn't take two clicks.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  Rectangle {
    anchors.centerIn: parent
    width: 20
    height: 20
    radius: width / 2

    color: Theme.accentSoft
    opacity: Tones.active ? 1 : 0
    scale: Tones.active ? 1 : 0.5

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutBack
      }
    }
  }

  Text {
    id: glyph

    // Driven by the pulse below rather than animating `opacity` directly, so
    // that stopping a tone restores full opacity instead of leaving the glyph
    // wherever the animation happened to be when it was cut off.
    property real pulse: 1

    anchors.centerIn: parent
    text: Icons.sineWave
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: Tones.active || popup.opened || mouse.containsMouse ? Theme.accent : Theme.fgDim

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    scale: mouse.pressed ? 0.86 : mouse.containsMouse ? 1.12 : 1

    Behavior on scale {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.OutBack
      }
    }

    opacity: Tones.active ? pulse : 1

    // Slow, so it reads as sustained rather than as an alert.
    SequentialAnimation on pulse {
      running: Tones.active
      loops: Animation.Infinite

      NumberAnimation {
        to: 0.45
        duration: 1400
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        to: 1.0
        duration: 1400
        easing.type: Easing.InOutSine
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      if (event.button === Qt.RightButton && Tones.active) {
        Tones.stop();
        return;
      }
      popup.toggle();
    }
  }

  TonesPopup {
    id: popup
    anchorItem: root
  }
}
