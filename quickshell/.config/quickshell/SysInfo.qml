// SysInfo.qml — CPU, memory and disk usage.
//
// One long-lived shell loop feeds this rather than re-spawning processes on a
// timer. It prints six numbers every two seconds:
//
//   cpuTotalJiffies cpuIdleJiffies memTotalKb memAvailKb diskTotalKb diskUsedKb
//
// CPU has to be derived from the delta between two samples, which is why the
// raw jiffy counters come across rather than a percentage.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // All 0..1.
  property real cpu: 0
  property real memory: 0
  property real disk: 0

  property real memUsedGb: 0
  property real memTotalGb: 0
  property real diskUsedGb: 0
  property real diskTotalGb: 0

  property bool ready: false

  // Previous CPU sample; usage is meaningless until we have two.
  property var previousCpu: null

  Process {
    running: true
    command: ["sh", "-c", "while true; do awk '/^cpu /{t=0; for (i=2; i<=NF; i++) t+=$i; printf \"%d %d \", t, $5+$6}' /proc/stat; awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d %d \", t, a}' /proc/meminfo; df -kP / | awk 'NR==2{printf \"%d %d\\n\", $2, $3}'; sleep 2; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.ingest(line)
    }
  }

  function ingest(line) {
    const f = line.trim().split(/\s+/).map(Number);
    if (f.length < 6 || f.some(isNaN))
      return;

    const cpuTotal = f[0];
    const cpuIdle = f[1];
    const memTotal = f[2];
    const memAvail = f[3];
    const diskTotal = f[4];
    const diskUsed = f[5];

    if (root.previousCpu) {
      const deltaTotal = cpuTotal - root.previousCpu.total;
      const deltaIdle = cpuIdle - root.previousCpu.idle;
      if (deltaTotal > 0)
        root.cpu = Math.max(0, Math.min(1, (deltaTotal - deltaIdle) / deltaTotal));
    }
    root.previousCpu = {
      total: cpuTotal,
      idle: cpuIdle
    };

    if (memTotal > 0) {
      root.memory = (memTotal - memAvail) / memTotal;
      root.memUsedGb = (memTotal - memAvail) / 1048576;
      root.memTotalGb = memTotal / 1048576;
    }

    if (diskTotal > 0) {
      root.disk = diskUsed / diskTotal;
      root.diskUsedGb = diskUsed / 1048576;
      root.diskTotalGb = diskTotal / 1048576;
    }

    root.ready = true;
  }
}
