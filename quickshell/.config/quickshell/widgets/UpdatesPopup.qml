// UpdatesPopup.qml — what's pending, and a way to install it.
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Popup {
  id: root

  cardWidth: 340
  align: "right"

  // Repo first, then AUR, flattened into one list so a single Repeater can
  // render both with an "AUR" badge to tell them apart.
  readonly property var entries: {
    const out = [];
    for (const e of Updates.repo)
      out.push({
        name: e.name,
        from: e.from,
        to: e.to,
        age: e.age,
        aur: false
      });
    for (const e of Updates.aur)
      out.push({
        name: e.name,
        from: e.from,
        to: e.to,
        age: e.age,
        aur: true
      });
    return out;
  }

  // Runs the upgrade in a terminal rather than silently: pacman and the AUR
  // both ask questions worth reading.
  Process {
    id: launcher
    command: ["alacritty", "-e", "sh", "-c", Updates.aurHelper + " -Syu; printf '\\nDone — press enter to close.'; read _"]
  }

  // ------------------------------------------------------------------ header
  Item {
    width: parent.width
    height: 24

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "UPDATES"
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
        visible: Updates.count > 0
        text: Updates.repo.length + " repo  ·  " + Updates.aur.length + " AUR"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        color: Theme.fgDim
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: refreshHover.containsMouse ? Theme.hover : "transparent"

        Text {
          anchors.centerIn: parent
          text: Icons.refresh
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Updates.busy ? Theme.accent : Theme.fgDim

          RotationAnimation on rotation {
            running: Updates.busy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1100
          }
        }

        MouseArea {
          id: refreshHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Updates.refresh()
        }
      }
    }
  }

  // ------------------------------------------------------------ empty states
  Text {
    width: parent.width
    visible: !Updates.checkedOnce
    text: "Checking for updates…"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fgDim
  }

  Row {
    width: parent.width
    spacing: 8
    visible: Updates.checkedOnce && Updates.count === 0

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.upToDate
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconSize
      color: Theme.good
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Everything is up to date."
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.fg
    }
  }

  // ------------------------------------------------------------ package list
  Flickable {
    width: parent.width
    height: Math.min(contentHeight, 250)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    visible: root.entries.length > 0

    Column {
      id: listColumn
      width: parent.width
      spacing: 1

      Repeater {
        model: root.entries

        delegate: Item {
          id: pkg

          required property var modelData

          width: listColumn.width
          height: 32

          Column {
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.right: badge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
              width: parent.width
              text: pkg.modelData.name
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: Theme.fg
            }

            Text {
              width: parent.width
              visible: pkg.modelData.to.length > 0
              text: pkg.modelData.from + "  →  " + pkg.modelData.to + (pkg.modelData.age ? "   ·   " + pkg.modelData.age + " old" : "")
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 1
              color: Theme.fgDim
            }
          }

          Rectangle {
            id: badge

            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            visible: pkg.modelData.aur
            width: 30
            height: 16
            radius: 8
            color: Theme.accentSoft

            Text {
              anchors.centerIn: parent
              text: "AUR"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize - 2
              font.bold: true
              color: Theme.accent
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------ action
  Rectangle {
    width: parent.width
    height: 32
    radius: 9
    visible: Updates.count > 0
    color: installHover.containsMouse ? Theme.accent : Theme.accentSoft

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 7

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.download
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
        color: installHover.containsMouse ? Theme.base : Theme.accent
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Install " + Updates.count + " update" + (Updates.count === 1 ? "" : "s")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        color: installHover.containsMouse ? Theme.base : Theme.accent
      }
    }

    MouseArea {
      id: installHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        launcher.startDetached();
        root.close();
      }
    }
  }
}
