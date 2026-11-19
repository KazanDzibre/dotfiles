// DotClock.qml — the time as a 3x5 dot matrix, like a scoreboard: lit dots in
// the accent, the unlit ones left as faint ghosts. A dot that changes fades
// rather than jumps. The colon is two dots that beat slowly.
import QtQuick
import qs

Row {
  id: root

  // "16:48" — digits and a colon.
  property string text: ""
  property color color: Theme.accent
  property real dot: 2.2
  property real gap: 0.9

  spacing: 3

  // Rows of three cells, top to bottom.
  readonly property var font: ({
      "0": "111101101101111",
      "1": "010110010010111",
      "2": "111001111100111",
      "3": "111001111001111",
      "4": "101101111001001",
      "5": "111100111001111",
      "6": "111100111101111",
      "7": "111001001010010",
      "8": "111101111101111",
      "9": "111101111001111"
    })

  Repeater {
    model: root.text.length

    delegate: Item {
      id: cell

      required property int index
      readonly property string ch: root.text.charAt(index)
      readonly property bool digit: /[0-9]/.test(ch)
      readonly property string pattern: digit ? root.font[ch] : ""

      width: digit ? root.dot * 3 + root.gap * 2 : root.dot
      height: root.dot * 5 + root.gap * 4

      Repeater {
        model: cell.digit ? 15 : 0

        delegate: Rectangle {
          required property int index

          x: (index % 3) * (root.dot + root.gap)
          y: Math.floor(index / 3) * (root.dot + root.gap)
          width: root.dot
          height: root.dot
          radius: root.dot / 2
          color: cell.pattern.charAt(index) === "1" ? root.color : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.10)

          Behavior on color {
            ColorAnimation {
              duration: Theme.motionBase
            }
          }
        }
      }

      Repeater {
        model: cell.digit ? 0 : 2

        delegate: Rectangle {
          required property int index

          y: (index === 0 ? 1 : 3) * (root.dot + root.gap)
          width: root.dot
          height: root.dot
          radius: root.dot / 2
          color: root.color

          SequentialAnimation on opacity {
            running: root.visible && !cell.digit
            loops: Animation.Infinite
            NumberAnimation {
              to: 0.3
              duration: 900
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 1
              duration: 900
              easing.type: Easing.InOutSine
            }
          }
        }
      }
    }
  }
}
