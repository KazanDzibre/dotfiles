// SysInfoIsland.qml — system health and pending updates, both collapsed to a
// single glyph each. The detail lives in their panels.
import QtQuick
import qs

Row {
  id: root

  spacing: 11

  SysInfoButton {
    anchors.verticalCenter: parent.verticalCenter
  }

  UpdatesButton {
    anchors.verticalCenter: parent.verticalCenter
  }
}
