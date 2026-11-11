// ShortcutsPopup.qml — the cheatsheet: search commands, what the island does
// with a click or a scroll, and the bar's keybindings. Reached from the control
// center's Shortcuts button, or `help` in the island search.
//
// The keys listed here are bound in hypr/.config/hypr/hyprland.lua; change both
// together.
import QtQuick
import Quickshell
import qs

MorphPanel {
  id: root

  cardWidth: 400
  align: "right"
  contentSpacing: 6

  readonly property var sections: [
    {
      title: "SEARCH  ·  SUPER + SHIFT + D",
      rows: [["pick", "Pick a colour anywhere on screen"], ["note …", "Save a quick note"], ["note at 15:00 …", "A note that reminds you"], ["notes", "Open your notes in Neovim"], ["noted", "Tick notes off in the island"], ["?question", "Ask the AI"], ["200 + 15%", "Sums, copied with Enter"], ["time in tokyo", "Time zones, units and dates"], ["help", "This list"]]
    },
    {
      title: "THE ISLAND",
      rows: [["Click", "Player, notifications or Today"], ["Hold", "Quick toggles: Wi-Fi, Bluetooth, …"], ["Right click", "Play or pause"], ["Scroll", "Volume"], ["Swipe sideways", "Next or previous track"], ["Hover", "Peek at more detail"], ["Drop a file", "Park it on the shelf"], ["Scroll on Today", "Walk through the days"]]
    },
    {
      title: "KEYS",
      rows: [["Super Shift D", "Search"], ["Super Shift V", "Clipboard history"], ["Super Shift W", "Wallpaper picker"], ["Super Shift P", "Screenshot an area (also Print)"], ["Shift Print", "Screenshot the whole screen"], ["Super Shift A", "Keep awake"]]
    }
  ]

  Repeater {
    model: root.sections

    delegate: Column {
      id: section

      required property var modelData
      required property int index

      width: parent.width
      spacing: 4
      topPadding: index === 0 ? 0 : 10

      Text {
        text: section.modelData.title
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        font.bold: true
        font.letterSpacing: 1
        color: Theme.fgDim
        bottomPadding: 2
      }

      Repeater {
        model: section.modelData.rows

        delegate: Item {
          id: line

          required property var modelData

          width: section.width
          height: 26

          Rectangle {
            id: chip
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 16
            height: 22
            radius: 7
            color: Theme.raised

            Text {
              id: chipText
              anchors.centerIn: parent
              text: line.modelData[0]
              font.family: Theme.fontFamily
              font.pixelSize: Theme.smallSize + 1
              font.bold: true
              color: Theme.accent
            }
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 150
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: line.modelData[1]
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
