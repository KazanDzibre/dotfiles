// Drives.qml — connected USB storage, and ejecting it safely.
//
// Everything goes through udisks, the same service the file manager mounts
// drives with, so a drive mounted from Dolphin shows up here and can be ejected
// from here without root.
//
// Nothing polls. `udisksctl monitor` streams every change udisks sees, and any
// output from it just schedules one re-read of lsblk, which is the easy way to
// get disks, partitions and mountpoints as a tree of JSON.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // [{ path, name, size, mounted, partitions: [{ path, label, size, fstype, mountpoints }] }]
  property var drives: []
  readonly property bool hasDrives: drives.length > 0
  readonly property int mountedCount: drives.filter(d => d.mounted).length

  // The drive currently being ejected, or "" — one at a time.
  property string ejecting: ""

  // The last failure for each drive, keyed by its path. Always replaced
  // wholesale rather than mutated, or bindings on it would never notice.
  property var errors: ({})

  property bool stale: false

  function refresh() {
    if (lister.running) {
      root.stale = true;
      return;
    }
    lister.running = true;
  }

  function eject(drive) {
    if (root.ejecting !== "")
      return;

    const steps = ["set -e"];
    for (const part of drive.partitions) {
      if (part.mountpoints.length > 0)
        steps.push("udisksctl unmount --no-user-interaction -b " + root.quote(part.path));
    }
    // Unmounting has already flushed everything to the drive, so it is safe to
    // pull even if powering it off isn't allowed — exit 3 says exactly that.
    steps.push("udisksctl power-off --no-user-interaction -b " + root.quote(drive.path) + " || exit 3");

    ejector.driveName = drive.name;
    ejector.command = ["sh", "-c", steps.join("\n")];
    root.setError(drive.path, "");
    root.ejecting = drive.path;
    ejector.running = true;
  }

  function finishEject(code) {
    const path = root.ejecting;
    root.ejecting = "";

    if (code === 0)
      root.notify("USB drive ejected", ejector.driveName + " is safe to remove.");
    else if (code === 3)
      root.notify("USB drive unmounted", ejector.driveName + " is safe to remove, but couldn't be powered off.");
    else
      root.setError(path, root.friendlyError(ejectErrors.text));

    root.refresh();
  }

  function setError(path, message) {
    const next = Object.assign({}, root.errors);
    if (message)
      next[path] = message;
    else
      delete next[path];
    root.errors = next;
  }

  function friendlyError(stderr) {
    const text = (stderr || "").trim();
    if (/busy/i.test(text))
      return "Still in use. Close anything that has files open on it, then try again.";
    if (/NotAuthorized|not authorized/i.test(text))
      return "Ejecting this drive needs authentication.";
    const last = text.split("\n").filter(l => l.trim().length > 0).pop();
    return last ? last.replace(/^.*Error\.[A-Za-z]+:\s*/, "") : "Couldn't eject the drive.";
  }

  function notify(summary, body) {
    notifier.command = ["notify-send", "-a", "Drives", "-i", "drive-removable-media", summary, body];
    notifier.startDetached();
  }

  function quote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
  }

  // lsblk has printed these as both booleans and "0"/"1" across versions.
  function truthy(v) {
    return v === true || v === 1 || v === "1";
  }

  function prettySize(s) {
    return String(s ?? "").replace(/^([0-9.]+)([KMGTPE])$/, "$1 $2B");
  }

  function parse(json) {
    const out = [];
    for (const disk of json.blockdevices ?? []) {
      if (disk.type !== "disk")
        continue;
      // USB sticks and card readers report their transport; `hotplug` and `rm`
      // together catch removable media on other buses. Internal NVMe and zram
      // have neither.
      if (disk.tran !== "usb" && !(root.truthy(disk.hotplug) && root.truthy(disk.rm)))
        continue;

      const parts = (disk.children ?? []).filter(p => p.fstype);
      // A stick formatted without a partition table carries its filesystem on
      // the disk itself.
      if (disk.fstype)
        parts.unshift(disk);

      const partitions = parts.map(p => ({
            path: p.path,
            label: p.label ?? "",
            size: root.prettySize(p.size),
            fstype: p.fstype ?? "",
            mountpoints: (p.mountpoints ?? []).filter(m => m)
          }));

      const name = [disk.vendor, disk.model].map(s => (s ?? "").trim()).filter(s => s.length > 0).join(" ");

      out.push({
        path: disk.path,
        name: name.length > 0 ? name : disk.name,
        size: root.prettySize(disk.size),
        mounted: partitions.some(p => p.mountpoints.length > 0),
        partitions: partitions
      });
    }
    return out;
  }

  Process {
    id: lister

    command: ["lsblk", "-J", "-o", "PATH,NAME,TYPE,TRAN,RM,HOTPLUG,SIZE,LABEL,VENDOR,MODEL,FSTYPE,MOUNTPOINTS"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.drives = root.parse(JSON.parse(text));
        } catch (e) {
          console.warn("Drives: couldn't read lsblk output:", e);
        }
      }
    }

    onExited: {
      if (root.stale) {
        root.stale = false;
        Qt.callLater(root.refresh);
      }
    }
  }

  Process {
    id: ejector

    property string driveName: ""

    stderr: StdioCollector {
      id: ejectErrors
    }

    // Deferred a turn so the stderr collector has definitely finished.
    onExited: code => Qt.callLater(() => root.finishEject(code))
  }

  Process {
    id: notifier
  }

  Process {
    id: monitor

    command: ["udisksctl", "monitor"]
    running: true

    stdout: SplitParser {
      onRead: settle.restart()
    }

    // udisks restarting ends the monitor; come back rather than go blind.
    onExited: restartMonitor.start()
  }

  Timer {
    id: restartMonitor
    interval: 5000
    onTriggered: monitor.running = true
  }

  // Plugging a drive in produces a burst of events. Read lsblk once, after it.
  Timer {
    id: settle
    interval: 350
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
