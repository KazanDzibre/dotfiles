// CalendarPopup.qml — month view that drops out of the clock island.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  readonly property int cell: 30

  // Sized so the inner content column is exactly seven cells wide.
  cardWidth: cell * 7 + 28
  contentSpacing: 8
  align: "center"

  // Which month the grid is showing. Snaps back to today every time it opens,
  // so browsing ahead never leaves it stale.
  property int viewYear: Time.now.getFullYear()
  property int viewMonth: Time.now.getMonth()

  onOpenedChanged: {
    if (opened) {
      root.viewYear = Time.now.getFullYear();
      root.viewMonth = Time.now.getMonth();
    }
  }

  function shiftMonth(delta) {
    let m = root.viewMonth + delta;
    let y = root.viewYear;
    while (m < 0) {
      m += 12;
      y -= 1;
    }
    while (m > 11) {
      m -= 12;
      y += 1;
    }
    root.viewMonth = m;
    root.viewYear = y;
  }

  // Day numbers padded to whole weeks; 0 means "blank cell".
  readonly property var cells: {
    const firstDay = new Date(viewYear, viewMonth, 1).getDay();
    const lead = (firstDay + 6) % 7;   // Monday-first
    const days = new Date(viewYear, viewMonth + 1, 0).getDate();
    const out = [];
    for (let i = 0; i < lead; i++)
      out.push(0);
    for (let d = 1; d <= days; d++)
      out.push(d);
    while (out.length % 7 !== 0)
      out.push(0);
    return out;
  }

  readonly property bool showingThisMonth: viewYear === Time.now.getFullYear() && viewMonth === Time.now.getMonth()

  // ---------------------------------------------------------- month header
  Item {
    width: parent.width
    height: 24

    Text {
      anchors.centerIn: parent
      text: Qt.formatDateTime(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      color: Theme.fg
    }

    Repeater {
      model: [
        {
          glyph: Icons.chevronLeft,
          delta: -1,
          left: true
        },
        {
          glyph: Icons.chevronRight,
          delta: 1,
          left: false
        }
      ]

      delegate: Rectangle {
        required property var modelData

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: modelData.left ? parent.left : undefined
        anchors.right: modelData.left ? undefined : parent.right

        width: 22
        height: 22
        radius: 11
        color: arrowMouse.containsMouse ? Theme.hover : "transparent"

        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          font.family: Theme.fontFamily
          font.pixelSize: Theme.iconSize
          color: Theme.fgDim
        }

        MouseArea {
          id: arrowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.shiftMonth(modelData.delta)
        }
      }
    }
  }

  // --------------------------------------------------------- weekday header
  Row {
    Repeater {
      model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

      delegate: Text {
        required property var modelData
        required property int index

        width: root.cell
        horizontalAlignment: Text.AlignHCenter
        text: modelData
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        font.bold: true
        color: index >= 5 ? Theme.accent : Theme.fgDim
        opacity: 0.8
      }
    }
  }

  // -------------------------------------------------------------- day grid
  Grid {
    columns: 7

    Repeater {
      model: root.cells

      delegate: Item {
        id: day

        required property var modelData
        required property int index

        readonly property bool isToday: root.showingThisMonth && modelData === Time.now.getDate()
        readonly property bool isWeekend: index % 7 >= 5

        width: root.cell
        height: 27

        Rectangle {
          anchors.centerIn: parent
          width: 25
          height: 25
          radius: 13
          visible: day.isToday
          color: Theme.accent
        }

        Text {
          anchors.centerIn: parent
          visible: day.modelData !== 0
          text: day.modelData
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: day.isToday
          color: day.isToday ? Theme.base : day.isWeekend ? Theme.fgDim : Theme.fg
        }
      }
    }
  }
}
