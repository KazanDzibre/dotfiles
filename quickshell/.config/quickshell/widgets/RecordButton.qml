// RecordButton.qml — the screen recording, living at the far right of the bar.
//
// It used to take over the centre island, which made the island unusable for
// anything else (search, notifications, the player) for as long as a recording
// ran. Its pill (see Bar.qml) only exists while recording, so it costs no bar
// space the rest of the time. Click anywhere on it to stop.
import QtQuick
import qs

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: 18

  Row {
    id: row

    anchors.centerIn: parent
    spacing: 7

    // The dot pulses while recording; hovering turns it into the stop square so
    // the click has an obvious meaning.
    Item {
      width: Theme.iconSize
      height: Theme.iconSize
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.centerIn: parent
        visible: !mouse.containsMouse
        width: 10
        height: 10
        radius: 5
        color: Theme.crit

        SequentialAnimation on opacity {
          running: Recorder.recording && !mouse.containsMouse
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.3
            duration: 700
          }
          NumberAnimation {
            to: 1
            duration: 700
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: mouse.containsMouse
        text: Icons.stop
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: Theme.crit
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Recorder.formatTime(Recorder.seconds)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      color: Theme.crit
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    anchors.margins: -6
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Recorder.stop()
  }
}
