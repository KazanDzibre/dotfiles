// Media.qml — which MPRIS player the bar is talking about.
//
// Both the bar button and the controller panel read from here, so they can
// never disagree about what "the current player" means.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
  id: root

  // Set from the panel when you explicitly pick a player; cleared when that
  // player goes away so the automatic choice takes over again.
  property string preferredDbusName: ""

  readonly property var players: Mpris.players ? Array.from(Mpris.players.values) : []

  readonly property var active: {
    if (players.length === 0)
      return null;
    if (preferredDbusName.length > 0) {
      const chosen = players.find(p => p.dbusName === preferredDbusName);
      if (chosen)
        return chosen;
    }
    // Whatever is actually playing wins, so the bar follows the audio rather
    // than whichever app registered first.
    return players.find(p => p.isPlaying) ?? players[0];
  }

  readonly property bool hasPlayer: active !== null
  readonly property bool playing: hasPlayer && active.isPlaying

  readonly property string title: hasPlayer ? (active.trackTitle ?? "") : ""
  readonly property string artist: hasPlayer ? (active.trackArtist ?? "") : ""
  readonly property string album: hasPlayer ? (active.trackAlbum ?? "") : ""
  readonly property string artUrl: hasPlayer ? (active.trackArtUrl ?? "") : ""

  readonly property bool seekable: hasPlayer && active.canSeek && active.lengthSupported && active.length > 0
  readonly property real position: hasPlayer && active.positionSupported ? active.position : 0
  readonly property real length: hasPlayer && active.lengthSupported ? active.length : 0

  // The panel sets this while it is open.
  property bool trackPosition: false

  // MPRIS position is a cached value that only refreshes when asked. Poking
  // the change signal re-reads it from the player; without this the progress
  // bar would sit still for the whole track.
  Timer {
    running: root.trackPosition && root.playing && root.hasPlayer
    interval: 1000
    repeat: true
    onTriggered: {
      if (root.active)
        root.active.positionChanged();
    }
  }

  // ------------------------------------------------------------ cover colour
  // The liveliest colour on the current cover, for tinting the island. Covers
  // are usually remote, so this fetches once per track and remembers it. If
  // anything fails, or the cover is grey, hasCoverTint stays false and the
  // island keeps the theme's accent.
  property color coverTint: "transparent"
  property bool hasCoverTint: false
  property var tintCache: ({})

  readonly property string tintScript: [
    'case "$1" in',
    '  file://*) magick "${1#file://}" -resize 48x -colors 6 -unique-colors txt:- ;;',
    "  http://*|https://*) curl -sfL --proto '=https,http' --max-time 6 --max-filesize 5000000 -- \"$1\" | magick - -resize 48x -colors 6 -unique-colors txt:- ;;",
    'esac'
  ].join("\n")

  onArtUrlChanged: root.updateTint()

  function updateTint() {
    if (root.artUrl.length === 0) {
      root.hasCoverTint = false;
      return;
    }
    const known = root.tintCache[root.artUrl];
    if (known !== undefined) {
      root.applyTint(known);
      return;
    }
    tintProcess.url = root.artUrl;
    tintProcess.exec(["sh", "-c", root.tintScript, "sh", root.artUrl]);
  }

  function applyTint(hex) {
    root.hasCoverTint = hex.length > 0;
    if (root.hasCoverTint)
      root.coverTint = hex;
  }

  // Same rule as Theme's accent: most saturated and bright, forced readable.
  function pickTint(output) {
    let best = null;
    let bestScore = 0;
    for (const hex of output.match(/#[0-9A-Fa-f]{6}/g) ?? []) {
      const c = Qt.color(hex);
      const score = c.hsvSaturation * (0.4 + c.hsvValue);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    if (!best || best.hsvSaturation < 0.18)
      return "";
    return Qt.hsva(Math.max(0, best.hsvHue), Math.min(1, best.hsvSaturation * 1.15), Math.max(0.82, best.hsvValue), 1).toString();
  }

  Process {
    id: tintProcess

    property string url: ""

    stdout: StdioCollector {
      onStreamFinished: {
        const hex = root.pickTint(text);
        const next = Object.assign({}, root.tintCache);
        next[tintProcess.url] = hex;
        root.tintCache = next;
        if (tintProcess.url === root.artUrl)
          root.applyTint(hex);
      }
    }
  }

  function select(player) {
    root.preferredDbusName = player ? player.dbusName : "";
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0)
      return "0:00";
    const total = Math.floor(seconds);
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    return mins + ":" + (secs < 10 ? "0" : "") + secs;
  }
}
