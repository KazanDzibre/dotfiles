pragma Singleton

// Shelf.qml — files parked in the island. Only remembers where they are; the
// files themselves are never moved or copied, and the list resets with the shell.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var items: []           // [{ path, name, image }]
  readonly property int count: items.length

  IpcHandler {
    target: "shelf"

    function add(path: string): void {
      root.addPaths([path]);
    }
  }

  function addUrls(urls) {
    root.addPaths(Array.from(urls).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))));
  }

  function addPaths(paths) {
    const next = root.items.slice();
    for (const path of paths) {
      if (!path.startsWith("/") || next.some(i => i.path === path))
        continue;
      next.unshift({
        path: path,
        name: path.substring(path.lastIndexOf("/") + 1),
        image: /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path)
      });
    }
    root.items = next;
  }

  function remove(path) {
    root.items = root.items.filter(i => i.path !== path);
  }

  function clear() {
    root.items = [];
  }

  function open(path) {
    Quickshell.execDetached(["xdg-open", path]);
  }

  // As a file, so pasting into a file manager or chat drops the real thing.
  function copy(path) {
    Quickshell.execDetached(["sh", "-c", 'printf "file://%s\\n" "$1" | wl-copy -t text/uri-list', "sh", path]);
  }
}
