// SegmentClock.qml — the time as an old seven-segment display: lit segments in
// a glowing colour, the unlit ones left as faint ghosts, as on a real LED clock.
// A segment that changes fades rather than jumps. The colon beats slowly.
import QtQuick
import qs

Row {
  id: root

  // "16:48" — digits and colons.
  property string text: ""
  property color color: "#ff5a3c"
  property real digitHeight: 16
  property real digitWidth: 9
  property real thickness: 2

  spacing: 4

  // a b c d e f g, lit per digit.
  readonly property var lit: ({
      "0": "abcdef",
      "1": "bc",
      "2": "abdeg",
      "3": "abcdg",
      "4": "bcfg",
      "5": "acdfg",
      "6": "acdefg",
      "7": "abc",
      "8": "abcdefg",
      "9": "abcdfg"
    })

  Repeater {
    model: root.text.length

    delegate: Item {
      id: cell

      required property int index
      readonly property string ch: root.text.charAt(index)
      readonly property bool digit: /[0-9]/.test(ch)
      readonly property string on: digit ? root.lit[ch] : ""

      width: digit ? root.digitWidth : 4
      height: root.digitHeight

      // One segment: where it sits and whether it is lit.
      component Seg: Rectangle {
        required property string id_
        property real sx: 0
        property real sy: 0
        property real sw: 0
        property real sh: 0

        x: sx
        y: sy
        width: sw
        height: sh
        radius: Math.min(sw, sh) / 2
        visible: cell.digit
        color: cell.on.indexOf(id_) >= 0 ? root.color : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.09)

        Behavior on color {
          ColorAnimation {
            duration: 260
          }
        }
      }

      readonly property real t: root.thickness
      readonly property real w: root.digitWidth
      readonly property real h: root.digitHeight
      readonly property real half: h / 2

      Seg {
        id_: "a"
        sx: cell.t * 0.5
        sy: 0
        sw: cell.w - cell.t
        sh: cell.t
      }
      Seg {
        id_: "g"
        sx: cell.t * 0.5
        sy: cell.half - cell.t / 2
        sw: cell.w - cell.t
        sh: cell.t
      }
      Seg {
        id_: "d"
        sx: cell.t * 0.5
        sy: cell.h - cell.t
        sw: cell.w - cell.t
        sh: cell.t
      }
      Seg {
        id_: "f"
        sx: 0
        sy: cell.t * 0.7
        sw: cell.t
        sh: cell.half - cell.t * 1.2
      }
      Seg {
        id_: "b"
        sx: cell.w - cell.t
        sy: cell.t * 0.7
        sw: cell.t
        sh: cell.half - cell.t * 1.2
      }
      Seg {
        id_: "e"
        sx: 0
        sy: cell.half + cell.t * 0.5
        sw: cell.t
        sh: cell.half - cell.t * 1.2
      }
      Seg {
        id_: "c"
        sx: cell.w - cell.t
        sy: cell.half + cell.t * 0.5
        sw: cell.t
        sh: cell.half - cell.t * 1.2
      }

      // The colon.
      Repeater {
        model: cell.digit ? 0 : 2

        delegate: Rectangle {
          required property int index

          x: (cell.width - 2.4) / 2
          y: index === 0 ? cell.h * 0.3 : cell.h * 0.7 - 2.4
          width: 2.4
          height: 2.4
          radius: 1.2
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
