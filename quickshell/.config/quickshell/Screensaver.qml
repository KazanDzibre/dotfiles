// Screensaver.qml — starting the screensaver by hand, and reporting when it
// will start by itself.
//
// The idle timeout belongs to hypridle rather than to the bar, because it has
// to keep working when Quickshell isn't running. So instead of a second copy of
// the number here that could drift out of date, it is read straight out of
// hypridle.conf, and the power menu shows whatever that file says.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string command: Quickshell.env("HOME") + "/.config/screensaver/screensaver"

  // Seconds of idle before hypridle starts it; 0 when hypridle.conf has no
  // listener that does.
  property int idleSeconds: 0

  // Without the daemon nothing happens on idle, whatever the file says.
  property bool daemonRunning: false

  function start() {
    launcher.command = [root.command, "start", "--manual"];
    launcher.startDetached();
  }

  function refresh() {
    if (!probe.running)
      probe.running = true;
  }

  function describe(seconds) {
    return seconds < 60 ? seconds + "s" : Math.round(seconds / 60) + " min";
  }

  function parse(conf) {
    // hypridle blocks don't nest, so splitting on the keyword and cutting at
    // the first closing brace is all the parsing this needs.
    for (const chunk of conf.split(/^\s*listener\s*\{/m).slice(1)) {
      const body = chunk.split("}")[0];
      if (!/^\s*on-timeout\s*=.*screensaver\s+start/m.test(body))
        continue;
      const match = body.match(/^\s*timeout\s*=\s*(\d+)/m);
      if (match)
        return parseInt(match[1]);
    }
    return 0;
  }

  Process {
    id: launcher
  }

  Process {
    id: probe

    command: ["pgrep", "-x", "hypridle"]
    onExited: code => root.daemonRunning = code === 0
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    watchChanges: true

    onFileChanged: reload()
    onLoaded: root.idleSeconds = root.parse(text())
    onLoadFailed: root.idleSeconds = 0
  }

  Component.onCompleted: refresh()
}
