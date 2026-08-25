// SysInfoPopup.qml — CPU, memory and disk, with the numbers the bar has no
// room for.
import QtQuick
import Quickshell
import qs

Popup {
  id: root

  cardWidth: 290
  align: "right"

  function gb(value) {
    return value.toFixed(value < 10 ? 1 : 0);
  }

  Item {
    width: parent.width
    height: 18

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "SYSTEM"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: !SysInfo.ready
      text: "reading…"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  MetricBar {
    width: parent.width
    glyph: Icons.cpu
    label: "Processor"
    value: SysInfo.cpu
  }

  MetricBar {
    width: parent.width
    glyph: Icons.memory
    label: "Memory"
    value: SysInfo.memory
    detail: root.gb(SysInfo.memUsedGb) + " / " + root.gb(SysInfo.memTotalGb) + " GB"
  }

  MetricBar {
    width: parent.width
    glyph: Icons.disk
    label: "Disk"
    value: SysInfo.disk
    detail: root.gb(SysInfo.diskUsedGb) + " / " + root.gb(SysInfo.diskTotalGb) + " GB"
  }
}
