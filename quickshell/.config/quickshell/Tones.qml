// Tones.qml — a pure sine tone at one of the "healing" frequencies.
//
// There is no audio file anywhere: mpv synthesises the tone from libavfilter's
// sine generator, so a frequency is just a number and the catalogue below costs
// nothing to extend.
//
// mpv is kept alive for the whole listening session and driven over its JSON
// IPC protocol rather than restarted per frequency. That buys three things:
// switching tones is a `loadfile` instead of a process teardown, the volume
// slider moves the tone that is already sounding, and every stop and switch can
// ramp the volume down first — a pure sine cut dead pops, which rather undoes
// the point of the exercise.
//
// The commands go in over mpv's *stdin* (`--input-ipc-client=fd://0`) rather
// than the more usual unix socket. A socket has to be created by mpv and then
// connected to, and there is no reliable moment to attempt that connection:
// too early and it is refused, on a retry timer and each attempt aborts the
// last one before it can land. stdin exists from the instant the process does,
// so the race simply doesn't arise.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // The six Solfeggio tones, the three "extended" ones above them, and 432 Hz,
  // which is not Solfeggio at all but is the one everybody actually asks for.
  readonly property var catalogue: [
    {
      hz: 174,
      name: "Foundation",
      note: "Grounding"
    },
    {
      hz: 285,
      name: "Repair",
      note: "Restoration"
    },
    {
      hz: 396,
      name: "Release",
      note: "Letting fear go"
    },
    {
      hz: 417,
      name: "Change",
      note: "Undoing the stuck"
    },
    {
      hz: 432,
      name: "Verdi tuning",
      note: "Calmer than 440"
    },
    {
      hz: 528,
      name: "Transformation",
      note: "The famous one"
    },
    {
      hz: 639,
      name: "Connection",
      note: "Relationships"
    },
    {
      hz: 741,
      name: "Clearing",
      note: "Expression"
    },
    {
      hz: 852,
      name: "Intuition",
      note: "Inner order"
    },
    {
      hz: 963,
      name: "Oneness",
      note: "Stillness"
    }
  ]

  // 0 while silent, otherwise the frequency currently sounding.
  property int playing: 0
  readonly property bool active: playing > 0

  property real volume: 0.35

  // Which frequency mpv was last handed. Only differs from `playing` for the
  // few hundred milliseconds a fade-and-swap takes.
  property int loaded: 0

  // ------------------------------------------------------------ focus timer
  // A countdown that runs alongside (or without) a tone. Kept against a wall
  // clock deadline rather than counted down tick by tick, so a busy shell can't
  // make it drift. When it runs out the tone stops and `timerFinished` fires.
  property int timerTotal: 0
  property real timerEnd: 0
  property int timerLeft: 0
  readonly property bool timing: timerLeft > 0
  readonly property real timerProgress: timerTotal > 0 ? 1 - timerLeft / timerTotal : 0
  readonly property var timerPresets: [15, 25, 50]

  signal timerFinished

  // Paused, the deadline is set aside and the time left frozen; resuming sets
  // a fresh deadline from what was left.
  property bool timerPaused: false

  function startTimer(minutes) {
    root.timerPaused = false;
    root.timerTotal = minutes * 60;
    root.timerEnd = Date.now() + root.timerTotal * 1000;
    root.timerLeft = root.timerTotal;
  }

  function stopTimer() {
    root.timerPaused = false;
    root.timerTotal = 0;
    root.timerLeft = 0;
  }

  function pauseTimer(paused) {
    if (!root.timing || paused === root.timerPaused)
      return;
    root.timerPaused = paused;
    if (!paused)
      root.timerEnd = Date.now() + root.timerLeft * 1000;
  }

  function addToTimer(minutes) {
    if (!root.timing)
      return;
    root.timerTotal += minutes * 60;
    root.timerLeft += minutes * 60;
    root.timerEnd += minutes * 60 * 1000;
  }

  function formatLeft(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  Timer {
    running: root.timing && !root.timerPaused
    interval: 250
    repeat: true
    onTriggered: {
      const left = Math.max(0, Math.ceil((root.timerEnd - Date.now()) / 1000));
      if (left !== root.timerLeft)
        root.timerLeft = left;
      if (left === 0) {
        root.timerTotal = 0;
        root.stop();
        root.timerFinished();
      }
    }
  }

  function urlFor(hz) {
    return "av://lavfi:sine=frequency=" + hz + ":sample_rate=48000";
  }

  function nameFor(hz) {
    for (const t of root.catalogue) {
      if (t.hz === hz)
        return t.name;
    }
    return "";
  }

  // Clicking the tone that is already playing stops it, which is what you reach
  // for when a tile is lit.
  function toggle(hz) {
    if (root.playing === hz)
      root.stop();
    else
      root.play(hz);
  }

  function play(hz) {
    root.playing = hz;

    if (!player.running) {
      root.loaded = hz;
      player.command = ["mpv", "--no-config", "--no-video", "--no-terminal", "--idle=yes", "--loop-file=inf", "--gapless-audio=yes", "--audio-client-name=quickshell-tone",
        // A sine that arrives instantly reads as a fault rather than as a
        // sound. The filter chain outlives each `loadfile`, so every tone gets
        // this, not just the first.
        "--af=afade=t=in:st=0:d=0.9", "--volume=" + root.mpvVolume(), "--input-ipc-client=fd://0", root.urlFor(hz)];
      player.running = true;
      return;
    }

    fade.next = hz;
    fade.begin();
  }

  function stop() {
    root.playing = 0;

    if (!player.running)
      return;

    fade.next = 0;
    fade.begin();
  }

  function setVolume(v) {
    root.volume = Math.max(0, Math.min(1, v));
    volumeFile.setText(root.volume.toFixed(3));

    // Mid-ramp the fade owns the volume; letting the slider write too would
    // fight it, and it is restored on the way out anyway.
    if (!fade.running)
      root.send(["set_property", "volume", root.mpvVolume()]);
  }

  // mpv's scale is 0..100. Squared, because a linear slider on a sustained sine
  // is unusable across its bottom half.
  function mpvVolume() {
    return root.scaled(root.volume);
  }

  function scaled(v) {
    return Math.round(v * v * 100);
  }

  function send(command) {
    if (!player.running)
      return false;

    // Written before mpv has finished starting is fine — it sits in the pipe
    // until mpv gets round to reading it.
    player.write(JSON.stringify({
      command: command
    }) + "\n");
    return true;
  }

  Process {
    id: player

    onExited: {
      root.playing = 0;
      root.loaded = 0;
      fade.stop();
    }
  }

  // The ramp out, used both for stopping and for swapping tones. ~330ms: long
  // enough to lose the pop, short enough that the tone still feels like it
  // stopped when you clicked.
  Timer {
    id: fade

    // The frequency to load once the ramp reaches silence, or 0 to quit.
    property int next: 0
    property real level: 0

    interval: 40
    repeat: true

    // Deliberately not restarting the level when a ramp is already under way —
    // clicking a third tile mid-swap should redirect it, not jump the volume
    // back up first.
    function begin() {
      if (fade.running)
        return;
      fade.level = root.volume;
      fade.start();
    }

    onTriggered: {
      level -= 0.12;

      if (level > 0) {
        root.send(["set_property", "volume", root.scaled(level)]);
        return;
      }

      stop();

      if (fade.next === 0) {
        root.send(["quit"]);
        return;
      }

      if (root.send(["loadfile", root.urlFor(fade.next)]))
        root.loaded = fade.next;
      // Straight back to full: the afade filter does the ramp in.
      root.send(["set_property", "volume", root.mpvVolume()]);
    }
  }

  // So a tone can be reached without the mouse:
  //   qs ipc call tones play 528
  //   qs ipc call tones stop
  // which is also what a `bind = ..., exec, qs ipc call tones ...` line in
  // hyprland.conf needs.
  IpcHandler {
    target: "tones"

    function play(hz: int): void {
      root.play(hz);
    }

    function stop(): void {
      root.stop();
    }

    function toggle(hz: int): void {
      root.toggle(hz);
    }

    function state(): string {
      return (root.active ? root.playing + " Hz" : "silent") + " at " + root.mpvVolume() + "%";
    }
  }

  // Remembered across restarts, like the theme mode.
  FileView {
    id: volumeFile

    path: Quickshell.cachePath("tone-volume")

    onLoaded: {
      const saved = parseFloat(text().trim());
      if (!isNaN(saved))
        root.volume = Math.max(0, Math.min(1, saved));
    }
    onLoadFailed: Qt.callLater(() => volumeFile.setText(root.volume.toFixed(3)))
  }
}
