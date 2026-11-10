// Updates.qml — pending package updates: pacman + AUR on Arch, apt on Ubuntu.
//
// Which one applies is decided in scripts/updates.sh, not here, so this file is
// the same on both machines. `aur` is simply empty on apt.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // Each entry is { name, from, to }.
  property var repo: []
  property var aur: []

  property bool busy: false
  // True while the upgrade terminal UpdatesPopup launched is still open.
  property bool installing: false
  property bool checkedOnce: false

  readonly property int count: repo.length + aur.length

  readonly property string script: Quickshell.shellPath("scripts/updates.sh")

  // "pacman", "apt" or "none"; drives the wording in the popup.
  property string manager: "pacman"
  readonly property bool hasAur: manager === "pacman"

  Process {
    running: true
    command: ["bash", root.script, "manager"]
    stdout: StdioCollector {
      onStreamFinished: root.manager = text.trim() || "none"
    }
  }

  Process {
    id: proc

    command: ["bash", root.script, "check"]

    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }

    onExited: {
      root.busy = false;
      root.checkedOnce = true;
    }
  }

  function refresh() {
    if (proc.running)
      return;
    root.busy = true;
    proc.running = true;
  }

  function parse(output) {
    const parts = output.split("@@AUR@@");
    root.repo = root.toEntries(parts[0]);
    root.aur = root.toEntries(parts.length > 1 ? parts[1] : "");
  }

  // checkupdates prints "pkgname 1.2.3-1 -> 1.2.4-1".
  // yay -Qua appends how long the package has been out of date, as in
  // "pkgname 1.2.3-1 -> 1.2.4-1 [11d22h]", so the version match must not be
  // anchored to the end of the line.
  function toEntries(block) {
    return block.split("\n").map(l => l.trim()).filter(l => l.length > 0).map(line => {
      const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)(?:\s+\[([^\]]+)\])?/);
      if (m)
        return {
          name: m[1],
          from: m[2],
          to: m[3],
          age: m[4] ?? ""
        };
      return {
        name: line.split(/\s+/)[0],
        from: "",
        to: "",
        age: ""
      };
    });
  }

  // Both checkupdates and the AUR helper hit the network, so don't fire the
  // moment the config loads — a burst of edits would mean a burst of checks.
  Timer {
    running: true
    interval: 5000
    onTriggered: root.refresh()
  }

  Timer {
    running: true
    interval: 10 * 60 * 1000
    repeat: true
    onTriggered: root.refresh()
  }

  // ----------------------------------------------------------- installing
  // Runs the upgrade in a terminal rather than silently: pacman, the AUR and
  // apt all ask questions worth reading. The island shows progress meanwhile.
  function install() {
    if (root.installing)
      return;
    if (root.count === 0) {
      root.upToDate();
      root.refresh();
      return;
    }
    installer.startDetached();
    root.watchInstall();
  }

  // Asked to install with nothing pending.
  signal upToDate

  Process {
    id: installer
    command: ["bash", root.script, "term"]
  }

  // The upgrade runs detached (a reloading shell must never kill pacman), so
  // whether it is still going is checked by looking for the process.
  function watchInstall() {
    root.installing = true;
    installPoll.misses = 0;
    installPoll.restart();
  }

  Timer {
    id: installPoll

    property int misses: 0

    interval: 2000
    repeat: true
    onTriggered: installCheck.running = true
  }

  Process {
    id: installCheck
    command: ["pgrep", "-f", "updates.sh upgrade"]

    onExited: code => {
      if (code === 0) {
        installPoll.misses = 0;
        return;
      }
      // Two misses in a row, so a slow terminal start can't end it early.
      installPoll.misses++;
      if (installPoll.misses >= 2) {
        installPoll.stop();
        root.installing = false;
        root.refresh();
      }
    }
  }
}
