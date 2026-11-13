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
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/waypaper/config.ini"
  readonly property string cacheDir: home + "/.cache/quickshell/wallpaper-thumbs"

  property string folder: home + "/Nuketown/Wallpapers"
  // First frames of the video wallpapers: what hyprpaper, pywal and the reveal
  // animation see, since none of them can read a video.
  readonly property string framesDir: home + "/.cache/quickshell/video-frames"

  property var files: []           // absolute source paths, sorted by name
  property var thumbs: ({})        // source path -> path to load for display
  property var palettes: ({})      // source path -> [hex, ...] dark to light
  property string current: ""      // the one waypaper currently has applied
  property bool applying: false
  property bool scanning: false

  // ------------------------------------------------------------- parallax
  // The wallpaper slides a little with the workspace (ParallaxWallpaper.qml):
  // one step per workspace, at most `parallaxSteps` steps, so it never runs out
  // of picture. On by default; the switch is on the control center's
  // wallpaper card, and the choice is remembered.
  property bool parallax: true
  readonly property real parallaxStep: 36
  readonly property int parallaxSteps: 4

  FileView {
    id: parallaxFile
    path: Quickshell.cachePath("parallax.json")

    onLoaded: {
      try {
        root.parallax = JSON.parse(text()).enabled !== false;
      } catch (e) {
        root.parallax = true;
      }
    }
    onLoadFailed: Qt.callLater(() => parallaxFile.setText(JSON.stringify({
          enabled: true
        })))
  }

  function setParallax(on) {
    root.parallax = on;
    parallaxFile.setText(JSON.stringify({
      enabled: on
    }));
  }

  // How much wider than the screen the wallpaper is drawn.
  function parallaxTravel(screenWidth) {
    return root.parallax ? root.parallaxStep * root.parallaxSteps : 0;
  }

  // How far left it is shifted on this screen right now: by the number of
  // the workspace it's showing, 1 at the far left, one step per number. By
  // number rather than by place in the list, because an empty workspace
  // vanishes as you leave it and would shift every place after it.
  function parallaxOffset(screen, screenWidth) {
    if (!root.parallax || !screen)
      return 0;
    const monitor = Hyprland.monitorFor(screen);
    const id = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1;
    return Math.max(0, Math.min(id - 1, root.parallaxSteps)) * root.parallaxStep;
  }

  // ------------------------------------------------------------ live video
  // A video wallpaper is a still (its first frame) applied exactly like any
  // other wallpaper, with the video played over it by ParallaxWallpaper. So the
  // theme, the reveal and the fallback all keep working, and a video is live
  // only while its own still is the wallpaper: pick anything else, from here or
  // from waypaper, and it stops by itself.
  property string liveVideo: ""
  property string liveStill: ""
  readonly property bool liveActive: liveVideo !== "" && liveStill === current
  // Decoding video costs power: on battery the still is shown instead.
  readonly property bool liveRunning: liveActive && !UPower.onBattery
  // What the picker should call "current": the video, not its still.
  readonly property string currentSource: liveActive ? liveVideo : current

  function isVideo(path) {
    return /\.(mp4|webm|mkv|mov)$/i.test(path);
  }

  function stillFor(path) {
    return root.framesDir + "/" + root.baseName(path) + ".png";
  }

  FileView {
    id: liveFile
    path: Quickshell.cachePath("live-wallpaper.json")

    onLoaded: {
      try {
        const saved = JSON.parse(text());
        root.liveVideo = saved.video ?? "";
        root.liveStill = saved.still ?? "";
      } catch (e) {
        root.liveVideo = "";
        root.liveStill = "";
      }
    }
    onLoadFailed: Qt.callLater(() => liveFile.setText("{}"))
  }

  function setLive(video) {
    root.liveVideo = video;
    root.liveStill = video.length > 0 ? root.stillFor(video) : "";
    liveFile.setText(JSON.stringify({
      video: root.liveVideo,
      still: root.liveStill
    }));
  }

  readonly property int currentIndex: files.indexOf(currentSource)
  readonly property int count: files.length

  function baseName(path) {
    return path.substring(path.lastIndexOf("/") + 1);
  }

  // Falls back to the full-size original if the thumbnail isn't built yet.
  function thumbFor(path) {
    return root.thumbs[path] ?? path;
  }

  function paletteFor(path) {
    return root.palettes[path] ?? [];
  }

  // The colour this wallpaper would most likely become the shell's accent:
  // the same "liveliest swatch, forced bright" rule Theme applies to pywal's
  // output, run on our own quantised palette so it is known before applying.
  function accentFor(path) {
    let best = Theme.accent;
    let bestScore = -1;
    for (const hex of root.paletteFor(path)) {
      const c = Qt.color(hex);
      const score = c.hsvSaturation * (0.4 + c.hsvValue);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    if (bestScore < 0)
      return best;
    return Qt.hsva(Math.max(0, best.hsvHue), Math.min(1.0, best.hsvSaturation * 1.15), Math.max(0.78, best.hsvValue), 1.0);
  }

  // --------------------------------------------------------------- scanning
  // Emits "<source>\t<image to display>" per wallpaper, generating any missing
  // thumbnail on the way. Nice'd because this is entirely background work.
  property var pending: []

  // The script is passed $1 = cache dir, $2 = wallpaper folder, so neither path
  // ever has to survive being spliced into shell quoting.
  //
  // Each line out is "<source>\t<thumbnail>\t<palette>", the palette being up to
  // five hex colours ImageMagick quantises the thumbnail down to. Both caches
  // persist, so this is slow only the first time an image is seen.
  readonly property string scanScript: [
    'CACHE="$1"; DIR="$2"; FRAMES="$3"; mkdir -p "$CACHE" "$FRAMES"',
    "find \"$DIR\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) | sort | while IFS= read -r f; do",
    // A video is shown by its first frame, pulled out once.
    '  case "$f" in',
    '    *.[mM][pP]4|*.[wW][eE][bB][mM]|*.[mM][kK][vV]|*.[mM][oO][vV])',
    '      src="$FRAMES/$(basename "$f").png"',
    '      if [ ! -s "$src" ] || [ "$f" -nt "$src" ]; then nice -n 19 ffmpeg -y -loglevel error -i "$f" -frames:v 1 "$src" </dev/null; fi',
    '      [ -s "$src" ] || continue;;',
    '    *) src="$f";;',
    '  esac',
    '  out="$CACHE/$(basename "$f").jpg"; pal="$CACHE/$(basename "$f").pal"',
    '  if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then nice -n 19 magick "$src" -resize 720x -quality 82 "$out" >/dev/null 2>&1; fi',
    '  [ -f "$out" ] && show="$out" || show="$src"',
    '  if [ ! -s "$pal" ] || [ "$show" -nt "$pal" ]; then nice -n 19 magick "$show" -resize 64x -colors 5 -unique-colors txt:- 2>/dev/null | grep -o "#[0-9A-Fa-f]\\{6\\}" | tr "\\n" " " > "$pal"; fi',
    '  printf "%s\\t%s\\t%s\\n" "$f" "$show" "$(cat "$pal" 2>/dev/null)"',
    'done'
  ].join("\n")

  Process {
    id: scanner

    command: ["sh", "-c", root.scanScript, "sh", root.cacheDir, root.folder, root.framesDir]

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
    const palette = (parts[2] ?? "").trim().split(/\s+/).filter(c => c.length === 7).sort((a, b) => Qt.color(a).hslLightness - Qt.color(b).hslLightness);
    const next = root.pending.slice();
    next.push({
      source: source,
      display: display,
      palette: palette
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
    const pals = {};
    for (const e of root.pending) {
      map[e.source] = e.display;
      pals[e.source] = e.palette;
    }

    if (JSON.stringify(sources) !== JSON.stringify(root.files))
      root.files = sources;
    if (JSON.stringify(map) !== JSON.stringify(root.thumbs))
      root.thumbs = map;
    if (JSON.stringify(pals) !== JSON.stringify(root.palettes))
      root.palettes = pals;
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

  // ------------------------------------------------------------------ picker
  // Each bar's WallpaperButton owns the picker for its own screen and opens it
  // when this names that screen. Reachable without the mouse:
  //   qs ipc call wallpaper picker
  // or bound to a key via the `quickshell:wallpaperPicker` global shortcut.
  signal pickerToggleRequested(string screenName)

  function togglePicker() {
    root.pickerToggleRequested(Hyprland.focusedMonitor?.name ?? "");
  }

  IpcHandler {
    target: "wallpaper"

    function picker(): void {
      root.togglePicker();
    }

    // Sets a wallpaper by path, with the same reveal as picking it.
    function set(path: string): void {
      root.apply(path);
    }
  }

  GlobalShortcut {
    appid: "quickshell"
    name: "wallpaperPicker"
    description: "Open the wallpaper picker"
    onPressed: root.togglePicker()
  }

  // ------------------------------------------------------------------ reveal
  // WallpaperReveal.qml listens for this and grows the new image outward from
  // the middle of each screen, on a layer just above hyprpaper. waypaper must
  // NOT run until that circle covers every screen: hyprpaper swaps instantly, so
  // starting it alongside the animation shows the new wallpaper behind the
  // growing circle instead of the old one. Each reveal surface reports in via
  // revealCovered(); the last one starts waypaper. The fallback timer covers a
  // surface that never reports (image failed to load, no screens).
  signal revealRequested(string path)

  property string queuedPath: ""
  property string queuedVideo: ""
  property int coveredCount: 0

  function revealCovered() {
    if (root.queuedPath.length === 0)
      return;
    root.coveredCount += 1;
    if (root.coveredCount >= Quickshell.screens.length)
      root.launchQueued();
  }

  function launchQueued() {
    coverFallback.stop();
    const path = root.queuedPath;
    const video = root.queuedVideo;
    root.queuedPath = "";
    root.queuedVideo = "";
    root.coveredCount = 0;
    if (path.length === 0)
      return;
    // Remembered before waypaper writes its config, so the video is ready to
    // start the moment its still becomes the current wallpaper.
    root.setLive(video);
    setter.command = ["waypaper", "--wallpaper", path];
    setter.running = true;
  }

  Timer {
    id: coverFallback
    interval: 4000
    onTriggered: root.launchQueued()
  }

  function apply(path) {
    if (setter.running || root.queuedPath.length > 0 || path.length === 0)
      return;
    const video = root.isVideo(path);
    // A video that hasn't had its first frame pulled out yet can't be applied.
    if (video && root.thumbs[path] === undefined)
      return;
    root.applying = true;
    root.queuedVideo = video ? path : "";
    root.queuedPath = video ? root.stillFor(path) : path;
    root.coveredCount = 0;
    coverFallback.restart();
    root.revealRequested(root.queuedPath);
  }

  function random() {
    if (setter.running)
      return;
    root.applying = true;
    setter.command = ["waypaper", "--random"];
    setter.running = true;
  }
}
