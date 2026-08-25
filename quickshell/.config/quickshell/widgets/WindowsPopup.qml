// WindowsPopup.qml — every open window, with a live preview of the hovered one.
//
// The window list comes from the Wayland toplevel manager rather than Hyprland's
// IPC: Hyprland.toplevels starts out empty until something calls
// refreshToplevels(), whereas ToplevelManager is populated and correct from the
// moment the shell starts. Hyprland is still consulted, but only to decorate
// each row with its workspace number.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

Popup {
  id: root

  cardWidth: 380
  align: "center"

  property var hovered: null

  readonly property var windows: {
    const list = Array.from(ToplevelManager.toplevels.values);
    return list.sort((a, b) => {
      const wa = root.workspaceOf(a);
      const wb = root.workspaceOf(b);
      if (wa !== wb)
        return wa - wb;
      return (a.appId ?? "").localeCompare(b.appId ?? "");
    });
  }

  // Preview whatever the pointer is over; fall back to the focused window so
  // the panel is never blank on open.
  readonly property var previewTarget: hovered ?? ToplevelManager.activeToplevel ?? (windows.length > 0 ? windows[0] : null)

  function workspaceOf(toplevel) {
    for (const h of Array.from(Hyprland.toplevels.values)) {
      if (h.wayland === toplevel)
        return h.workspace ? h.workspace.id : -1;
    }
    return -1;
  }

  onOpenedChanged: {
    if (opened)
      Hyprland.refreshToplevels();   // populate the workspace numbers
    else
      root.hovered = null;
  }

  // -------------------------------------------------------------- header row
  Item {
    width: parent.width
    height: 20

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "OPEN WINDOWS"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.windows.length
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  // ------------------------------------------------------------ live preview
  Rectangle {
    width: parent.width
    height: 196
    radius: 10
    color: Theme.raised
    clip: true
    visible: root.windows.length > 0

    ScreencopyView {
      id: capture

      // Letterbox into the panel rather than stretching: windows are rarely
      // the same aspect as this box.
      readonly property real aspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6

      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height * aspect)
      height: width / aspect

      live: true
      captureSource: root.visible ? root.previewTarget : null

      opacity: hasContent ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: 160
        }
      }
    }

    // Not every surface can be captured; say so rather than showing a void.
    Column {
      anchors.centerIn: parent
      spacing: 6
      visible: !capture.hasContent

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Icons.windows
        font.family: Theme.fontFamily
        font.pixelSize: 26
        color: Theme.fgDim
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No preview available"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }
    }
  }

  Text {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    visible: root.previewTarget !== null
    text: root.previewTarget ? root.previewTarget.title : ""
    elide: Text.ElideMiddle
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallSize
    color: Theme.fgDim
  }

  // ------------------------------------------------------------ window list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 200)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: root.windows.length > 0

    Column {
      id: listColumn
      width: parent.width
      spacing: 2

      Repeater {
        model: root.windows

        delegate: Rectangle {
          id: row

          required property var modelData

          readonly property bool isActive: modelData === ToplevelManager.activeToplevel
          readonly property int workspace: root.workspaceOf(modelData)
          readonly property string iconUrl: Icons.themeIconFor(modelData.appId)

          width: listColumn.width
          height: 34
          radius: 9
          color: isActive ? Theme.accentSoft : rowHover.containsMouse ? Theme.hover : "transparent"

          Behavior on color {
            ColorAnimation {
              duration: Theme.animFast
            }
          }

          // Real themed app icon where one exists, Nerd Font glyph otherwise.
          IconImage {
            id: appIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.iconUrl !== ""
            source: row.iconUrl
            implicitSize: 18
            asynchronous: true
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.iconUrl === ""
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: Icons.forClass(row.modelData.appId)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
            color: Theme.accent
          }

          Column {
            anchors.left: parent.left
            anchors.leftMargin: 34
            anchors.right: closeButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              width: parent.width
              text: row.modelData.title
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: row.isActive ? Theme.accent : Theme.fg
            }

            Text {
              width: parent.width
              text: row.workspace >= 0 ? row.modelData.appId + "  ·  workspace " + row.workspace : row.modelData.appId
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 1
              color: Theme.fgDim
            }
          }

          Rectangle {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            opacity: rowHover.containsMouse || closeHover.containsMouse ? 1 : 0
            color: closeHover.containsMouse ? Theme.crit : "transparent"

            Behavior on opacity {
              NumberAnimation {
                duration: Theme.animFast
              }
            }

            Text {
              anchors.centerIn: parent
              text: Icons.close
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize + 2
              color: closeHover.containsMouse ? Theme.base : Theme.fgDim
            }

            MouseArea {
              id: closeHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: row.modelData.close()
            }
          }

          MouseArea {
            id: rowHover

            anchors.fill: parent
            anchors.rightMargin: 30      // leave the close button its own area
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: root.hovered = row.modelData
            onClicked: {
              row.modelData.activate();
              root.close();
            }
          }
        }
      }
    }
  }

  // -------------------------------------------------------------- empty state
  Text {
    width: parent.width
    visible: root.windows.length === 0
    text: "No open windows."
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }
}
