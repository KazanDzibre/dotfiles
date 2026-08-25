// Wallpaper.qml — a thin wrapper around waypaper.
//
// waypaper stays the source of truth: it owns the backend (hyprpaper here) and
// its post_command runs `wal -i`, which rewrites ~/.cache/wal/colors.json and
// therefore re-themes this whole bar. So setting a wallpaper from here recolours
// everything for free — see Theme.qml.
//
// The wallpapers themselves are 4-megapixel PNGs several megabytes each, and
// decoding twenty of those on demand takes seconds. So a scan pass shells out to
// ImageMagick once to build a cache of 720px JPEGs, and the UI only ever loads
// those. The cache persists, so it is only paid for once per image.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/waypaper/config.ini"
  readonly property string cacheDir: home + "/.cache/quickshell/wallpaper-thumbs"

  property string folder: home + "/Nuketown/Wallpapers"

  property var files: []           // absolute source paths, sorted by name
  property var thumbs: ({})        // source path -> path to load for display
  property string current: ""      // the one waypaper currently has applied
  property bool applying: false
  property bool scanning: false

  readonly property int currentIndex: files.indexOf(current)
  readonly property int count: files.length

  function baseName(path) {
    return path.substring(path.lastIndexOf("/") + 1);
  }

  // Falls back to the full-size original if the thumbnail isn't built yet.
  function thumbFor(path) {
    return root.thumbs[path] ?? path;
  }

  // --------------------------------------------------------------- scanning
  // Emits "<source>\t<image to display>" per wallpaper, generating any missing
  // thumbnail on the way. Nice'd because this is entirely background work.
  property var pending: []

  Process {
    id: scanner

    command: ["sh", "-c", "CACHE=\"" + root.cacheDir + "\"; mkdir -p \"$CACHE\"; find '" + root.folder + "' -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) | sort | while IFS= read -r f; do out=\"$CACHE/$(basename \"$f\").jpg\"; if [ ! -f \"$out\" ] || [ \"$f\" -nt \"$out\" ]; then nice -n 19 magick \"$f\" -resize 720x -quality 82 \"$out\" >/dev/null 2>&1; fi; if [ -f \"$out\" ]; then printf '%s\\t%s\\n' \"$f\" \"$out\"; else printf '%s\\t%s\\n' \"$f\" \"$f\"; fi; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => root.collect(line)
    }

    onExited: root.commit()
  }

  function rescan() {
    if (scanner.running)
      return;
    root.pending = [];
    root.scanning = true;
    scanner.running = true;
  }

  function collect(line) {
    const parts = line.split("\t");
    if (parts.length < 2)
      return;
    const source = parts[0].trim();
    const display = parts[1].trim();
    if (source.length === 0)
      return;
    const next = root.pending.slice();
    next.push({
      source: source,
      display: display
    });
    root.pending = next;
  }

  // Only publish at the end, and only if something actually changed: the popup
  // rescans every time it opens, and reassigning the model would rebuild every
  // delegate and restart the carousel animation for no reason.
  function commit() {
    root.scanning = false;

    const sources = root.pending.map(e => e.source);
    const map = {};
    for (const e of root.pending)
      map[e.source] = e.display;

    if (JSON.stringify(sources) !== JSON.stringify(root.files))
      root.files = sources;
    if (JSON.stringify(map) !== JSON.stringify(root.thumbs))
      root.thumbs = map;
  }

  // Build the cache shortly after startup so the panel is instant when it is
  // first opened, rather than making the user wait then.
  Timer {
    running: true
    interval: 2000
    onTriggered: root.rescan()
  }

  // ------------------------------------------------------------ current state
  // Read waypaper's own config rather than shelling out to `waypaper --list`:
  // watching the file means we also notice wallpapers set from waypaper's GUI
  // or from the CLI, not just the ones set from here.
  FileView {
    path: root.configPath
    watchChanges: true

    onFileChanged: reload()
    onLoaded: root.parseConfig(text())
  }

  function parseConfig(contents) {
    for (const line of contents.split("\n")) {
      const m = line.match(/^\s*wallpaper\s*=\s*(.+?)\s*$/);
      if (m) {
        let path = m[1];
        if (path.startsWith("~"))
          path = root.home + path.substring(1);
        root.current = path;
        return;
      }
    }
  }

  // ------------------------------------------------------------------ setting
  Process {
    id: setter
    onExited: root.applying = false
  }

  function apply(path) {
    if (setter.running || path.length === 0)
      return;
    root.applying = true;
    setter.command = ["waypaper", "--wallpaper", path];
    setter.running = true;
  }

  function random() {
    if (setter.running)
      return;
    root.applying = true;
    setter.command = ["waypaper", "--random"];
    setter.running = true;
  }
}
