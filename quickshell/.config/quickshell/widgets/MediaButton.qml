// MediaButton.qml — the analyser in the bar; click for the controller.
//
// Deliberately a fixed width: the bars never change the island's size, so a
// track change can't shuffle the whole right-hand side of the bar.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: spectrum.implicitWidth
  implicitHeight: 18

  Spectrum {
    id: spectrum
    anchors.centerIn: parent
    color: popup.opened || mouse.containsMouse ? Theme.accent : Media.playing ? Theme.accent : Theme.fgDim
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    anchors.margins: -4        // a 23px target is small; widen the hit area
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: event => {
      if (event.button === Qt.MiddleButton) {
        if (Media.active)
          Media.active.togglePlaying();
        return;
      }
      popup.toggle();
    }
  }

  WheelHandler {
    onWheel: event => {
      if (!Media.active)
        return;
      if (event.angleDelta.y > 0)
        Media.active.previous();
      else
        Media.active.next();
    }
  }

  MediaPopup {
    id: popup
    anchorItem: root
  }
}
