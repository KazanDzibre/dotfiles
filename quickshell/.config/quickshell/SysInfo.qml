// SysInfo.qml — CPU, memory and disk usage, plus hardware temperatures.
//
// One long-lived shell loop feeds this rather than re-spawning processes on a
// timer. It prints seven numbers every two seconds:
//
//   cpuTotalJiffies cpuIdleJiffies memTotalKb memAvailKb diskTotalKb diskUsedKb netBytes
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

  // Network traffic in bytes per second, and the last stretch of it and CPU
  // for the status pill's graph. `busy` needs a couple of readings to switch on
  // and several calm ones to switch off, so the graph doesn't flicker.
  property real netRate: 0
  readonly property int historyLength: 18
  property var cpuHistory: []
  property var netHistory: []
  property bool busy: false
  property int hotRun: 0
  property int calmRun: 0
  property var previousNet: null

  // Previous CPU sample; usage is meaningless until we have two.
  property var previousCpu: null

  // One entry per meaningful sensor, in display order, from scripts/temps.py:
  //   { key, label, temp (°C), high, crit }
  // Empty until the first line arrives, and stays empty on a machine with no
  // readable sensors -- the panel hides the section rather than showing zeroes.
  property var temps: []
  readonly property bool hasTemps: temps.length > 0
  readonly property real cpuTemp: {
    for (const sensor of temps) {
      if (sensor.key === "cpu")
        return sensor.temp;
    }
    return 0;
  }

  // The sensor closest to its own trip point, and that distance as a 0..1 load
  // so a bar or a tint can be driven off it the way CPU/memory/disk are.
  readonly property var hottest: {
    let best = null;
    for (const sensor of temps) {
      if (!best || root.tempFraction(sensor) > root.tempFraction(best))
        best = sensor;
    }
    return best;
  }
  readonly property real tempLoad: hottest ? root.tempFraction(hottest) : 0

  // Scaled against each chip's own trip point rather than a fixed ceiling,
  // because "hot" is per-device: an NVMe throttles where a CPU is still fine.
  // 30 °C is the floor -- nothing idles below it, so measuring from 0 would
  // waste half the bar.
  function tempFraction(sensor) {
    const crit = sensor.crit > 35 ? sensor.crit : 95;
    return Math.max(0, Math.min(1, (sensor.temp - 30) / (crit - 30)));
  }

  // Separate from the loop above: temperatures need no delta, change slowly,
  // and the sensors have to be re-discovered each pass because hwmon numbering
  // is not stable across boots. A missing python3 leaves `temps` empty, which
  // the panel treats as "this machine has no sensors" rather than failing.
  Process {
    running: true
    command: ["python3", Quickshell.shellPath("scripts/temps.py"), "--watch", "5"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.ingestTemps(line)
    }
  }

  function ingestTemps(line) {
    try {
      const payload = JSON.parse(line);
      root.temps = payload.sensors ?? [];
    } catch (e) {
      // A partial line is not worth a warning; the next one is 5s away.
    }
  }

  Process {
    running: true
    command: ["sh", "-c", "while true; do awk '/^cpu /{t=0; for (i=2; i<=NF; i++) t+=$i; printf \"%d %d \", t, $5+$6}' /proc/stat; awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf \"%d %d \", t, a}' /proc/meminfo; df -kP / | awk 'NR==2{printf \"%d %d \", $2, $3}'; awk 'NR>2{sub(/^ +/, \"\"); split($0, f, /[: ]+/); if (f[1] !~ /^(lo|docker|veth|br-|virbr|tun|wg|tailscale)/) n+=f[2]+f[10]} END{printf \"%.0f\\n\", n}' /proc/net/dev; sleep 2; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.ingest(line)
    }
  }

  function ingest(line) {
    const f = line.trim().split(/\s+/).map(Number);
    if (f.length < 7 || f.some(isNaN))
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

    const now = Date.now();
    if (root.previousNet) {
      const seconds = (now - root.previousNet.at) / 1000;
      if (seconds > 0)
        root.netRate = Math.max(0, (f[6] - root.previousNet.bytes) / seconds);
    }
    root.previousNet = {
      bytes: f[6],
      at: now
    };

    root.netHistory = root.netHistory.concat([root.netRate]).slice(-root.historyLength);
    root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-root.historyLength);

    const hot = root.cpu >= 0.55 || root.netRate >= 1500000;
    root.hotRun = hot ? root.hotRun + 1 : 0;
    root.calmRun = hot ? 0 : root.calmRun + 1;
    if (root.hotRun >= 2)
      root.busy = true;
    else if (root.calmRun >= 5)
      root.busy = false;

    root.ready = true;
  }
}
