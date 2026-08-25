// ClipboardPopup.qml — searchable clipboard history.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  cardWidth: 360
  align: "right"

  property string query: ""

  // The bar only becomes focusable while this is open — see Bar.qml.
  readonly property bool wantsKeyboard: opened

  readonly property var results: {
    const all = Clipboard.entries;
    if (root.query.length === 0)
      return all;
    const needle = root.query.toLowerCase();
    return all.filter(e => e.toLowerCase().includes(needle));
  }

  onOpenedChanged: {
    root.query = "";
    if (opened)
      searchField.forceActiveFocus();
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 22

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "CLIPBOARD"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Clipboard.count + " kept"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: Clipboard.count > 0
        width: 22
        height: 22
        radius: 11
        color: clearHover.containsMouse ? Theme.crit : "transparent"

        Text {
          anchors.centerIn: parent
          text: Icons.clearAll
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: clearHover.containsMouse ? Theme.base : Theme.fgDim
        }

        MouseArea {
          id: clearHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Clipboard.clear()
        }
      }
    }
  }

  // ------------------------------------------------------------------ search
  Rectangle {
    width: parent.width
    height: 30
    radius: 8
    color: Theme.raised
    border.width: 1
    border.color: searchField.activeFocus ? Theme.accent : "transparent"
    visible: Clipboard.count > 0

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.search
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: Theme.fgDim
    }

    TextInput {
      id: searchField

      anchors.fill: parent
      anchors.leftMargin: 30
      anchors.rightMargin: 10
      verticalAlignment: TextInput.AlignVCenter

      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fg
      selectionColor: Theme.accent
      selectedTextColor: Theme.base
      clip: true

      text: root.query
      onTextChanged: root.query = text

      Keys.onEscapePressed: root.close()
      Keys.onReturnPressed: {
        if (root.results.length > 0) {
          Clipboard.copy(root.results[0]);
          root.close();
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: searchField.text.length === 0
        text: "Search history…"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fgDim
      }
    }
  }

  // ------------------------------------------------------------------- list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 320)
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: root.results.length > 0

    Column {
      id: list
      width: parent.width
      spacing: 2

      Repeater {
        model: root.results

        delegate: Rectangle {
          id: row

          required property var modelData
          required property int index

          readonly property int lines: Clipboard.lineCount(modelData)

          width: list.width
          height: 34
          radius: 8
          color: rowHover.containsMouse ? Theme.hover : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }

          // Position in history — the top entry is what a plain paste gives you.
          Text {
            id: indexLabel
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            text: row.index === 0 ? "▸" : row.index + 1
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize
            color: row.index === 0 ? Theme.accent : Theme.fgDim
          }

          Text {
            anchors.left: indexLabel.right
            anchors.leftMargin: 8
            anchors.right: badge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: Clipboard.preview(row.modelData)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
          }

          // Multi-line clippings are flattened in the preview, so say how much
          // is actually there.
          Text {
            id: badge
            anchors.right: removeButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: row.lines > 1
            text: row.lines + " lines"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallSize - 1
            color: Theme.fgDim
          }

          Rectangle {
            id: removeButton

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 10
            opacity: rowHover.containsMouse || removeHover.containsMouse ? 1 : 0
            color: removeHover.containsMouse ? Theme.crit : "transparent"

            Behavior on opacity {
              NumberAnimation {
                duration: Theme.animFast
              }
            }

            Text {
              anchors.centerIn: parent
              text: Icons.close
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize
              color: removeHover.containsMouse ? Theme.base : Theme.fgDim
            }

            MouseArea {
              id: removeHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Clipboard.remove(row.modelData)
            }
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            anchors.rightMargin: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Clipboard.copy(row.modelData);
              root.close();
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ empty states
  Text {
    width: parent.width
    visible: Clipboard.count === 0
    text: "Nothing copied yet."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  Text {
    width: parent.width
    visible: Clipboard.count > 0 && root.results.length === 0
    text: "No matches."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }
}
