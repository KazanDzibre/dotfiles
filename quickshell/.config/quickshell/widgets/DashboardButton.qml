// DashboardButton.qml — opens the markets/news drawer.
//
// Left click toggles it; right click opens it straight onto the other tab, so
// you can go where you meant to in one press.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: 18
  implicitHeight: 18

  // Same halo the AI button uses, so the two drawers read as a matching pair.
  Rectangle {
    anchors.centerIn: parent
    width: 20
    height: 20
    radius: width / 2

    color: Theme.accentSoft
    opacity: Dashboard.open ? 1 : 0
    scale: Dashboard.open ? 1 : 0.5

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
    anchors.centerIn: parent
    text: Icons.dashboard
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconSize
    color: Dashboard.open || mouse.containsMouse ? Theme.accent : Theme.fgDim

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
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: event => {
      if (event.button === Qt.RightButton) {
        AiChat.close();
        Dashboard.show(Dashboard.tabs[(Dashboard.tabs.indexOf(Dashboard.tab) + 1) % Dashboard.tabs.length]);
        return;
      }
      AiChat.close();
      Dashboard.toggle();
    }
  }
}
