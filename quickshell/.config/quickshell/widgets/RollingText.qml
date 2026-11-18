// RollingText.qml — text whose characters roll over when they change, like a
// flip clock: the old one slides up and fades while the new one rises from
// below, with a small overshoot. Only the characters that changed move, so
// 14:09 -> 14:10 rolls the 09 and leaves the 14 where it is.
//
// `instantTail` characters at the end just swap, for a readout that changes
// ten times a second (a stopwatch's hundredths) and would only blur.
import QtQuick
import qs

Row {
  id: root

  property string text: ""
  property color color: Theme.fg
  property int pixelSize: Theme.fontSize
  property bool bold: false
  property int instantTail: 0
  property int duration: 320

  Repeater {
    model: root.text.length

    delegate: Item {
      id: cell

      required property int index
      readonly property string ch: root.text.charAt(index)
      readonly property bool instant: index >= root.text.length - root.instantTail
      property string shown: ""

      width: Math.max(cur.implicitWidth, old.opacity > 0 ? old.implicitWidth : 0)
      height: cur.implicitHeight
      clip: true

      Text {
        id: cur
        text: cell.ch
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: root.bold
        color: root.color
      }

      Text {
        id: old
        text: cell.shown
        opacity: 0
        font: cur.font
        color: root.color
      }

      onChChanged: {
        if (cell.shown !== "" && cell.shown !== cell.ch && !cell.instant && root.visible) {
          old.text = cell.shown;
          roll.restart();
        }
        cell.shown = cell.ch;
      }
      Component.onCompleted: cell.shown = cell.ch

      ParallelAnimation {
        id: roll

        NumberAnimation {
          target: old
          property: "y"
          from: 0
          to: -cell.height * 0.8
          duration: root.duration * 0.7
          easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: old
          property: "opacity"
          from: 0.9
          to: 0
          duration: root.duration * 0.7
        }
        NumberAnimation {
          target: cur
          property: "y"
          from: cell.height * 0.8
          to: 0
          duration: root.duration
          easing.type: Easing.OutBack
          easing.overshoot: 1.6
        }
        NumberAnimation {
          target: cur
          property: "opacity"
          from: 0
          to: 1
          duration: root.duration * 0.6
        }
      }
    }
  }
}
