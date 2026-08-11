// Time.qml — one clock for the whole shell.
//
// Ticks once a minute rather than once a second: nothing on the bar displays
// seconds, and this is a laptop.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  readonly property date now: clock.date

  readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
  readonly property string date: Qt.formatDateTime(clock.date, "ddd dd MMM")
  readonly property string longDate: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
