// Media.qml — which MPRIS player the bar is talking about.
//
// Both the bar button and the controller panel read from here, so they can
// never disagree about what "the current player" means.
pragma Singleton

import Quickshell
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
