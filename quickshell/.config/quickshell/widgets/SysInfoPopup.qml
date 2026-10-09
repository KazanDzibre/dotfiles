// SysInfoPopup.qml — CPU, memory, disk and hardware temperatures, with the
// numbers the bar has no room for.
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

  // ------------------------------------------------------------ temperatures
  // Hidden outright when nothing readable was found, rather than showing a
  // header over an empty space.
  Item {
    width: parent.width
    height: visible ? 18 : 0
    visible: SysInfo.hasTemps

    Text {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      text: "THERMALS"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      font.bold: true
      font.letterSpacing: 1
      color: Theme.fgDim
    }

    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      // The trip point the hottest sensor is being measured against, so the
      // bars have a stated scale instead of an implied one.
      text: SysInfo.hottest ? "trip " + Math.round(SysInfo.hottest.crit) + "°" : ""
      font.family: Theme.fontFamily
      font.pixelSize: Theme.smallSize
      color: Theme.fgDim
    }
  }

  Repeater {
    model: SysInfo.temps

    delegate: MetricBar {
      required property var modelData

      width: parent.width
      glyph: Icons.forSensor(modelData.key)
      label: modelData.label
      value: SysInfo.tempFraction(modelData)
      readout: Math.round(modelData.temp) + " °C"
    }
  }
}
