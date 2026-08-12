// AiAssistant.qml — a docked AI web app, toggled from the bar.
//
// Quickshell cannot host a browser itself: QtWebEngine has to be initialised
// before the application object exists, which Quickshell never does, and trying
// crashes the shell outright. So the assistant is a real Chromium window that
// Hyprland docks to the left edge, parked on the `special:ai` workspace so a
// single dispatch slides it in and out.
//
// Everything about *which* assistant it is comes from the environment:
//
//   QS_AI_NAME     label in the bar            (default "Kimi")
//   QS_AI_URL      web app to open             (default https://www.kimi.com/)
//   QS_AI_PROFILE  chromium profile directory  (default ~/Nuketown/Webapps/kimi-profile)
//   QS_AI_CLASS    window class *prefix*       (default "chrome-")
//   QS_AI_COMMAND  full launcher command; overrides URL/PROFILE. If you use it,
//                  its window class must start with QS_AI_CLASS.
//
// On the class: Chromium ignores --class in --app mode and derives the Wayland
// app id from the URL instead, e.g. "chrome-www.kimi.com__-Default". So both
// this file and the Hyprland rule match the "chrome-" prefix that every
// Chromium web app shares, rather than one hardcoded id. Changing QS_AI_URL is
// then the only edit needed to swap assistants — no rule change, no class to
// keep in sync. The cost is that any other Chromium web app would also be
// docked; set QS_AI_CLASS to the full id if you ever run two.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Singleton {
  id: root

  function envOr(name, fallback) {
    const value = Quickshell.env(name);
    return value && value.length > 0 ? value : fallback;
  }

  readonly property string home: Quickshell.env("HOME")

  readonly property string name: envOr("QS_AI_NAME", "Kimi")
  readonly property string url: envOr("QS_AI_URL", "https://www.kimi.com/")
  readonly property string profile: envOr("QS_AI_PROFILE", home + "/Nuketown/Webapps/kimi-profile")
  readonly property string classPrefix: envOr("QS_AI_CLASS", "chrome-")
  readonly property string customCommand: envOr("QS_AI_COMMAND", "")

  readonly property string workspace: "ai"

  // The window exists (may be hidden on the special workspace).
  readonly property var toplevel: {
    if (!ToplevelManager.toplevels)
      return null;
    return Array.from(ToplevelManager.toplevels.values).find(t => t.appId && t.appId.startsWith(root.classPrefix)) ?? null;
  }
  readonly property bool running: toplevel !== null

  // The special workspace is currently revealed.
  property bool shown: false

  onRunningChanged: {
    if (!running)
      root.shown = false;
  }

  // Track reveal state from Hyprland's own events rather than guessing, so
  // toggling the workspace by any other means keeps the bar icon honest.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "activespecial" && event.name !== "activespecialv2")
        return;
      const parts = event.data.split(",");
      // activespecial:   <workspaceName>,<monitor>
      // activespecialv2: <id>,<workspaceName>,<monitor>
      const wsName = event.name === "activespecial" ? parts[0] : parts[1];
      root.shown = wsName === "special:" + root.workspace;
    }
  }

  Process {
    id: launcher
  }

  function launch() {
    launcher.command = root.customCommand.length > 0 ? ["sh", "-c", root.customCommand] : ["chromium", "--app=" + root.url, "--user-data-dir=" + root.profile, "--ozone-platform-hint=auto", "--no-first-run"];
    launcher.startDetached();
  }

  function reveal() {
    Hyprland.dispatch("togglespecialworkspace " + root.workspace);
  }

  function toggle() {
    if (!root.running) {
      root.launch();
      revealWhenReady.restart();
      return;
    }
    root.reveal();
  }

  function quit() {
    if (root.toplevel)
      root.toplevel.close();
  }

  // The window rule parks it on the special workspace silently, so after
  // launching we have to wait for it to exist and then slide it in. Chromium
  // cold start is slow; give it 15 seconds before giving up.
  Timer {
    id: revealWhenReady

    property int ticks: 0

    interval: 250
    repeat: true

    onTriggered: {
      ticks++;
      if (root.running) {
        stop();
        ticks = 0;
        if (!root.shown)
          root.reveal();
        return;
      }
      if (ticks > 60) {
        stop();
        ticks = 0;
      }
    }
  }
}
