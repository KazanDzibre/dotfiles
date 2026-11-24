// GlyphSwap.qml — an icon that morphs when it changes: the old one shrinks and
// turns away while the new one arrives with a small overshoot. An icon that
// stays the same does nothing.
//
// Takes the properties of a Text that icons use (text, color, font, and the
// alignment, which is moot: the glyph is centred in its own box).
import QtQuick
import qs

Item {
  id: root

  property string text: ""
  property color color: Theme.fg
  property alias font: cur.font
  property int horizontalAlignment: Text.AlignHCenter
  property int verticalAlignment: Text.AlignVCenter

  property string previous: ""

  implicitWidth: cur.implicitWidth
  implicitHeight: cur.implicitHeight

  Behavior on color {
    ColorAnimation {
      duration: Theme.motionQuick
    }
  }

  onTextChanged: {
    if (previous !== "" && text !== previous && root.visible) {
      ghost.text = previous;
      ghostAnim.restart();
      curAnim.restart();
    }
    previous = text;
  }
  Component.onCompleted: previous = text

  Text {
    id: ghost
    anchors.centerIn: parent
    font: cur.font
    color: root.color
    opacity: 0
  }

  Text {
    id: cur
    anchors.centerIn: parent
    text: root.text
    font.family: Theme.iconFamily
    font.pixelSize: Theme.iconSize
    color: root.color
  }

  ParallelAnimation {
    id: ghostAnim
    NumberAnimation {
      target: ghost
      property: "opacity"
      from: 1
      to: 0
      duration: Theme.motionQuick
      easing.type: Easing.InQuad
    }
    NumberAnimation {
      target: ghost
      property: "scale"
      from: 1
      to: 0.55
      duration: Theme.motionQuick
      easing.type: Easing.InQuad
    }
    NumberAnimation {
      target: ghost
      property: "rotation"
      from: 0
      to: -25
      duration: Theme.motionQuick
      easing.type: Easing.InQuad
    }
  }

  ParallelAnimation {
    id: curAnim
    NumberAnimation {
      target: cur
      property: "opacity"
      from: 0
      to: 1
      duration: Theme.motionQuick
    }
    NumberAnimation {
      target: cur
      property: "scale"
      from: 0.55
      to: 1
      duration: Theme.motionQuick
      easing.type: Easing.OutBack
      easing.overshoot: 1.6
    }
    NumberAnimation {
      target: cur
      property: "rotation"
      from: 25
      to: 0
      duration: Theme.motionQuick
      easing.type: Easing.OutBack
      easing.overshoot: 1.6
    }
  }
}
