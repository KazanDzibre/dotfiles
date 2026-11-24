// ClipboardPopup.qml — searchable clipboard history.
import QtQuick
import Quickshell
import qs

MorphPanel {
  id: root

  cardWidth: 360
  align: "right"
  grabKeyboard: true

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
      font.family: Theme.textFamily
      font.features: Theme.tabular
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
        font.family: Theme.textFamily
        font.features: Theme.tabular
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
          font.family: Theme.iconFamily
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
      font.family: Theme.iconFamily
      font.pixelSize: Theme.iconSize
      color: Theme.fgDim
    }

    TextInput {
      id: searchField

      anchors.fill: parent
      anchors.leftMargin: 30
      anchors.rightMargin: 10
      verticalAlignment: TextInput.AlignVCenter

      font.family: Theme.textFamily
      font.features: Theme.tabular
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
        font.family: Theme.textFamily
        font.features: Theme.tabular
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
          readonly property var info: Clipboard.describe(modelData)

          // The row's text, with what matters in bold and the rest dim, as the
          // styled text Text understands. Everything is escaped first.
          function esc(t) {
            return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
          }
          function clip(t, n) {
            return t.length > n ? t.substring(0, n) + "…" : t;
          }
          readonly property string markup: {
            const dim = "<font color=\"" + Theme.fgDim + "\">";
            if (info.type === "link")
              return "<b>" + esc(info.host) + "</b> " + dim + esc(clip(info.rest, 80)) + "</font>";
            if (info.type === "file")
              return "<b>" + esc(info.name) + "</b> " + dim + esc(clip(info.folder, 80)) + "</font>";
            return esc(Clipboard.preview(modelData));
          }

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
            font.family: Theme.textFamily
            font.features: Theme.tabular
            font.pixelSize: Theme.smallSize
            color: row.index === 0 ? Theme.accent : Theme.fgDim
          }

          // A leading mark for what it is: a swatch for a colour, an icon for a
          // link or a file.
          Item {
            id: kindMark
            anchors.left: indexLabel.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: row.info.type === "text" ? 0 : 16
            height: 16
            visible: width > 0

            Rectangle {
              anchors.fill: parent
              visible: row.info.type === "color"
              radius: 8
              color: row.info.color ?? "transparent"
              border.width: 1
              border.color: Theme.border
            }
            Text {
              anchors.centerIn: parent
              visible: row.info.type === "link" || row.info.type === "file"
              text: row.info.type === "link" ? Icons.web : Icons.appFiles
              font.family: Theme.iconFamily
              font.pixelSize: Theme.fontSize
              color: Theme.accent
            }
          }

          Text {
            anchors.left: kindMark.right
            anchors.leftMargin: kindMark.visible ? 8 : 0
            anchors.right: badge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.markup
            textFormat: Text.StyledText
            elide: Text.ElideRight
            font.family: Theme.textFamily
            font.features: Theme.tabular
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
            font.family: Theme.textFamily
            font.features: Theme.tabular
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
              font.family: Theme.iconFamily
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
    font.family: Theme.textFamily
    font.features: Theme.tabular
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  Text {
    width: parent.width
    visible: Clipboard.count > 0 && root.results.length === 0
    text: "No matches."
    font.family: Theme.textFamily
    font.features: Theme.tabular
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }
}
