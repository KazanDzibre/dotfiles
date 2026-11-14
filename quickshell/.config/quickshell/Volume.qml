pragma Singleton

// Volume.qml — setting an output's or a microphone's volume and mute.
//
// Reading stays with Quickshell's Pipewire objects (node.audio.volume / muted
// follow every change). Writing goes through wpctl: on a Bluetooth output this
// Quickshell build's own setters only changed its copy of the number and never
// reached PipeWire, so the island and sliders seemed to work while the
// earbuds stayed as loud as before. wpctl is what the volume keys use, and it
// works the same for speakers, headphones and microphones.

import Quickshell
import QtQuick

Singleton {
  id: root

  function set(node, value) {
    if (!node || !node.audio)
      return;
    const v = Math.max(0, Math.min(1, value));
    // Also set it locally, so the slider or bar follows the pointer at once;
    // PipeWire's own update lands a moment later with the same number.
    node.audio.volume = v;
    Quickshell.execDetached(["wpctl", "set-volume", String(node.id), v.toFixed(3)]);
  }

  function nudge(node, delta) {
    if (node && node.audio)
      root.set(node, node.audio.volume + delta);
  }

  function setMuted(node, muted) {
    if (!node || !node.audio)
      return;
    node.audio.muted = muted;
    Quickshell.execDetached(["wpctl", "set-mute", String(node.id), muted ? "1" : "0"]);
  }

  function toggleMute(node) {
    if (node && node.audio)
      root.setMuted(node, !node.audio.muted);
  }
}
