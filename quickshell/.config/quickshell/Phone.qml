pragma Singleton

// Phone.qml — your phone, through KDE Connect: whether it's here, its battery,
// sending it files and pinging it.
//
// kdeconnectd is started by hyprland.lua. Pair once from the KDE Connect app on
// the phone (both on the same Wi-Fi, with ports 1714–1764 open in the
// firewall). On an iPhone, iOS suspends the app soon after you leave it, so the
// phone mostly shows as connected while the app is open; notifications and
// calls can't come across at all.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property string id: ""
  property string name: ""
  readonly property bool connected: id !== ""

  property int battery: -1
  property bool charging: false

  // Low enough to show a bubble beside the island.
  readonly property bool low: connected && battery >= 0 && battery <= 20 && !charging

  signal sending(string what)
  signal arrived(string name)

  // KDE Connect may simply not be installed (Ubuntu: package `kdeconnect`);
  // then there is nothing to poll, and polling a missing binary every few
  // seconds only fills the log.
  property bool available: false

  Process {
    running: true
    command: ["sh", "-c", "command -v kdeconnect-cli >/dev/null"]
    onExited: code => root.available = code === 0
  }

  // ------------------------------------------------------------- watching
  Timer {
    running: root.available
    repeat: true
    interval: 8000
    triggeredOnStart: true
    onTriggered: {
      // While it isn't here, also ask the network every few rounds: the
      // daemon doesn't search on its own, and an iPhone only answers while
      // the app is open.
      root.rounds++;
      if (!root.connected && root.rounds % 3 === 0)
        Quickshell.execDetached(["kdeconnect-cli", "--refresh"]);
      if (!finder.running)
        finder.running = true;
    }
  }
  property int rounds: 0

  // "<id> <name>" per paired phone that is reachable right now.
  Process {
    id: finder
    command: ["kdeconnect-cli", "--list-available", "--id-name-only"]

    stdout: StdioCollector {
      onStreamFinished: {
        const line = text.split("\n").map(l => l.trim()).find(l => l.length > 0) ?? "";
        const space = line.indexOf(" ");
        const id = space > 0 ? line.substring(0, space) : line;
        const name = space > 0 ? line.substring(space + 1) : "";
        const wasHere = root.connected;
        root.id = id;
        root.name = name || (id ? "Phone" : "");
        if (root.connected && !wasHere)
          root.arrived(root.name);
        if (root.connected && !batteryReader.running) {
          batteryReader.command = ["gdbus", "call", "--session", "--dest", "org.kde.kdeconnect", "--object-path", "/modules/kdeconnect/devices/" + root.id + "/battery", "--method", "org.freedesktop.DBus.Properties.GetAll", "org.kde.kdeconnect.device.battery"];
          batteryReader.running = true;
        }
        if (!root.connected)
          root.battery = -1;
      }
    }
  }

  // ({'charge': <85>, 'isCharging': <false>},)
  Process {
    id: batteryReader

    stdout: StdioCollector {
      onStreamFinished: {
        const charge = text.match(/'charge':\s*<(-?\d+)>/);
        const plugged = text.match(/'isCharging':\s*<(true|false)>/);
        root.battery = charge ? Number(charge[1]) : -1;
        root.charging = plugged ? plugged[1] === "true" : false;
      }
    }
  }

  // ---------------------------------------------------------------- doing
  function send(paths) {
    if (!root.connected || paths.length === 0)
      return;
    for (const path of paths)
      Quickshell.execDetached(["kdeconnect-cli", "--device", root.id, "--share", path]);
    root.sending(paths.length === 1 ? paths[0].substring(paths[0].lastIndexOf("/") + 1) : paths.length + " files");
  }

  function ping() {
    if (root.connected)
      Quickshell.execDetached(["kdeconnect-cli", "--device", root.id, "--ping-msg", "Here I am"]);
  }
}
