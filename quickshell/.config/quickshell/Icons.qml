// Icons.qml — Material Symbols Rounded glyphs (Theme.iconFamily), addressed by
// codepoint rather than pasted in literally so they survive copy/paste. Look a
// name up in the font's .codepoints file (google/material-design-icons,
// variablefont/); bootstrap/install-icon-font.sh installs the font itself.
// One family, one stroke: it sits next to Inter, and it is a variable font, so
// GlyphSwap can fill an icon in when its toggle is on.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // ---------------------------------------------------------------- pixmaps
  // Plenty of apps ship their icon only in the pixmaps folders, under a name
  // the icon theme doesn't have (Spotify's is "spotify-client"), and Qt doesn't
  // look there by itself. Name -> file, with the sharpest format winning.
  property var pixmaps: ({})

  Process {
    running: true
    command: ["sh", "-c", "find /usr/share/pixmaps \"$HOME/.local/share/pixmaps\" -maxdepth 1 \\( -type f -o -type l \\) 2>/dev/null"]

    stdout: StdioCollector {
      onStreamFinished: {
        const rank = {
          svg: 3,
          png: 2,
          xpm: 1
        };
        const found = {};
        for (const path of text.split("\n")) {
          const m = path.match(/([^\/]+)\.(svg|png|xpm)$/);
          if (m && (!found[m[1]] || rank[m[2]] > rank[found[m[1]].split(".").pop()]))
            found[m[1]] = path;
        }
        root.pixmaps = found;
      }
    }
  }

  // ------------------------------------------------------------------ audio
  readonly property string volHigh: String.fromCodePoint(0xe050)
  readonly property string volMed: String.fromCodePoint(0xe04d)
  readonly property string volLow: String.fromCodePoint(0xe04e)
  readonly property string volMute: String.fromCodePoint(0xe04f)

  // ---------------------------------------------------------------- battery
  // Index 0..10 maps to 0%..100% in ten-point steps.
  readonly property var batteryRamp: [String.fromCodePoint(0xebdc), String.fromCodePoint(0xf09c), String.fromCodePoint(0xf09c), String.fromCodePoint(0xf09d), String.fromCodePoint(0xf09e), String.fromCodePoint(0xf09e), String.fromCodePoint(0xf09f), String.fromCodePoint(0xf0a0), String.fromCodePoint(0xf0a0), String.fromCodePoint(0xf0a1), String.fromCodePoint(0xe1a5)]
  readonly property string batteryCharging: String.fromCodePoint(0xe1a3)
  readonly property string batteryAlert: String.fromCodePoint(0xe19c)
  readonly property string batteryUnknown: String.fromCodePoint(0xe1a6)

  // ---------------------------------------------------------------- network
  readonly property var wifiRamp: [String.fromCodePoint(0xf0b0), String.fromCodePoint(0xebe4), String.fromCodePoint(0xebd6), String.fromCodePoint(0xebe1), String.fromCodePoint(0xf065)]
  readonly property string wifiOff: String.fromCodePoint(0xe648)
  readonly property string ethernet: String.fromCodePoint(0xeb2f)
  readonly property string noNetwork: String.fromCodePoint(0xf239)

  // ------------------------------------------------------------------ media
  readonly property string play: String.fromCodePoint(0xe037)
  readonly property string pause: String.fromCodePoint(0xe034)
  readonly property string next: String.fromCodePoint(0xe044)
  readonly property string prev: String.fromCodePoint(0xe045)
  readonly property string music: String.fromCodePoint(0xe405)

  // -------------------------------------------------------------- calendar
  readonly property string calendar: String.fromCodePoint(0xe935)
  readonly property string chevronUp: String.fromCodePoint(0xe316)
  readonly property string chevronLeft: String.fromCodePoint(0xe5cb)
  readonly property string chevronRight: String.fromCodePoint(0xe5cc)

  // -------------------------------------------------------------- dashboard
  readonly property string dashboard: String.fromCodePoint(0xe871)
  readonly property string chart: String.fromCodePoint(0xe6e1)
  readonly property string newspaper: String.fromCodePoint(0xeb81)
  readonly property string devFeed: String.fromCodePoint(0xe86f)   // md-code_tags
  readonly property string trendUp: String.fromCodePoint(0xe8e5)
  readonly property string trendDown: String.fromCodePoint(0xe8e3)

  // ------------------------------------------------------ healing frequencies
  readonly property string sineWave: String.fromCodePoint(0xf154)

  // ------------------------------------------------------------ screensaver
  readonly property string screensaver: String.fromCodePoint(0xe30c)   // md-monitor_shimmer

  // ----------------------------------------------------------------- drives
  readonly property string usbDrive: String.fromCodePoint(0xe1e0)       // md-usb_flash_drive
  readonly property string eject: String.fromCodePoint(0xe8fb)

  // ------------------------------------------------------------------ tools
  readonly property string crop: String.fromCodePoint(0xe3be)
  readonly property string clipboard: String.fromCodePoint(0xe14f)
  readonly property string copy: String.fromCodePoint(0xe14d)
  readonly property string search: String.fromCodePoint(0xef7a)
  readonly property string coffee: String.fromCodePoint(0xefef)
  readonly property string coffeeOff: String.fromCodePoint(0xf1a5)

  // ---------------------------------------------------------- notifications
  readonly property string bell: String.fromCodePoint(0xe7f5)
  readonly property string bellOutline: String.fromCodePoint(0xe7f5)
  readonly property string bellOff: String.fromCodePoint(0xe7f6)
  readonly property string bellBadge: String.fromCodePoint(0xf4fe)
  readonly property string clearAll: String.fromCodePoint(0xe0b8)

  // ------------------------------------------------------------------- tray
  readonly property string chip: String.fromCodePoint(0xe322)

  // ------------------------------------------------------------ ai assistant
  readonly property string ai: String.fromCodePoint(0xe65f)
  readonly property string send: String.fromCodePoint(0xe163)
  readonly property string plus: String.fromCodePoint(0xe145)
  readonly property string web: String.fromCodePoint(0xea07)
  readonly property string key: String.fromCodePoint(0xe73c)
  readonly property string stop: String.fromCodePoint(0xe047)

  // ----------------------------------------------------------------- display
  readonly property string brightness: String.fromCodePoint(0xe518)
  readonly property string brightnessLow: String.fromCodePoint(0xe1ad)
  readonly property string warmth: String.fromCodePoint(0xf03d)
  readonly property string alert: String.fromCodePoint(0xf083)

  // ------------------------------------------------------------------ power
  readonly property string power: String.fromCodePoint(0xf8c7)
  readonly property string logout: String.fromCodePoint(0xe9ba)
  readonly property string restart: String.fromCodePoint(0xf053)
  readonly property string sleep: String.fromCodePoint(0xf159)

  // -------------------------------------------------------------- bluetooth
  readonly property string bluetooth: String.fromCodePoint(0xe1a7)
  readonly property string bluetoothOff: String.fromCodePoint(0xe1a9)
  readonly property string bluetoothConnected: String.fromCodePoint(0xe1a8)

  // ------------------------------------------------------------------ theme
  readonly property string sun: String.fromCodePoint(0xe518)
  readonly property string moon: String.fromCodePoint(0xe51c)

  // ---------------------------------------------------------------- windows
  readonly property string windows: String.fromCodePoint(0xe6fa)
  readonly property string tv: String.fromCodePoint(0xe63b)
  readonly property string unpark: String.fromCodePoint(0xf70d)   // pip_exit
  readonly property string replay10: String.fromCodePoint(0xe059)
  readonly property string forward10: String.fromCodePoint(0xe056)
  readonly property string close: String.fromCodePoint(0xe5cd)

  // ------------------------------------------------------------- wallpaper
  readonly property string wallpaper: String.fromCodePoint(0xe1bc)
  readonly property string timer: String.fromCodePoint(0xe425)
  readonly property string sparkle: String.fromCodePoint(0xe65f)
  readonly property string record: String.fromCodePoint(0xe837)
  readonly property string shelf: String.fromCodePoint(0xe1a1)
  readonly property string weatherCloudy: String.fromCodePoint(0xf15c)
  readonly property string weatherFog: String.fromCodePoint(0xe818)
  readonly property string weatherLightning: String.fromCodePoint(0xebdb)
  readonly property string weatherPartly: String.fromCodePoint(0xf172)
  readonly property string weatherRainy: String.fromCodePoint(0xf176)
  readonly property string weatherSnowy: String.fromCodePoint(0xe2cd)
  readonly property string weatherSunny: String.fromCodePoint(0xe81a)
  readonly property string bolt: String.fromCodePoint(0xea0b)

  // ------------------------------------------------------------ system info
  readonly property string cpu: String.fromCodePoint(0xe322)
  readonly property string memory: String.fromCodePoint(0xf7a3)
  readonly property string disk: String.fromCodePoint(0xf80e)
  readonly property string thermometer: String.fromCodePoint(0xe846)
  readonly property string gpu: String.fromCodePoint(0xe30d)       // md-expansion_card
  readonly property string motherboard: String.fromCodePoint(0xe30d)

  // A glyph per sensor key reported by scripts/temps.py.
  function forSensor(key) {
    if (key.startsWith("cpu"))
      return root.cpu;
    if (key.startsWith("gpu"))
      return root.gpu;
    if (key.startsWith("nvme") || key.startsWith("disk"))
      return root.disk;
    if (key.startsWith("battery"))
      return root.batteryUnknown;
    if (key.startsWith("board"))
      return root.motherboard;
    return root.thermometer;
  }

  // --------------------------------------------------------------- updates
  readonly property string updates: String.fromCodePoint(0xe8d7)
  readonly property string upToDate: String.fromCodePoint(0xf0be)
  readonly property string refresh: String.fromCodePoint(0xe5d5)
  readonly property string download: String.fromCodePoint(0xf090)
  readonly property string eyedropper: String.fromCodePoint(0xe3b8)
  readonly property string keyboard: String.fromCodePoint(0xe312)
  readonly property string phone: String.fromCodePoint(0xe7ba)
  readonly property string note: String.fromCodePoint(0xf1fc)
  readonly property string lightbulb: String.fromCodePoint(0xe90f)

  // -------------------------------------------------------------- interface
  readonly property string forget: String.fromCodePoint(0xe16f)
  readonly property string check: String.fromCodePoint(0xe668)
  readonly property string lock: String.fromCodePoint(0xe899)
  readonly property string spinner: String.fromCodePoint(0xe9d0)
  readonly property string eyeShow: String.fromCodePoint(0xe8f4)
  readonly property string eyeHide: String.fromCodePoint(0xe8f5)
  readonly property string mic: String.fromCodePoint(0xe31d)
  readonly property string micOff: String.fromCodePoint(0xe02b)

  // ------------------------------------------------------------ app icons
  readonly property string appGeneric: String.fromCodePoint(0xe5c3)
  readonly property string appTerminal: String.fromCodePoint(0xeb8e)
  readonly property string appBrowser: String.fromCodePoint(0xea07)
  readonly property string appEditor: String.fromCodePoint(0xe86f)
  readonly property string appFiles: String.fromCodePoint(0xe2c7)
  readonly property string appChat: String.fromCodePoint(0xe0c9)
  readonly property string appSettings: String.fromCodePoint(0xe8b8)

  // Real application icon from the icon theme, as a URL for Image/IconImage,
  // or "" when the theme has nothing for this app.
  //
  // DesktopEntries is tried first because a .desktop file names the icon
  // properly, but it silently yields nothing when XDG_DATA_DIRS is unset — so
  // fall back to treating the window class itself as an icon name, which is
  // right far more often than not.
  function themeIconFor(cls) {
    if (!cls)
      return "";

    const entry = DesktopEntries.heuristicLookup(cls);
    const fromEntry = entry ? root.themeIcon(entry.icon) : "";
    if (fromEntry)
      return fromEntry;

    const candidates = [cls, cls.toLowerCase(), cls.split(".").pop().toLowerCase()];
    for (const c of candidates) {
      if (c && Quickshell.hasThemeIcon(c))
        return Quickshell.iconPath(c);
    }
    return "";
  }

  // BlueZ reports a freedesktop icon name such as "audio-headset". Used as the
  // fallback when the icon theme has no matching image.
  function forBluetoothDevice(iconName) {
    const n = (iconName ?? "").toLowerCase();
    if (n.includes("headset") || n.includes("headphone"))
      return String.fromCodePoint(0xf01f);
    if (n.includes("speaker") || n.includes("audio"))
      return String.fromCodePoint(0xe32d);
    if (n.includes("mouse"))
      return String.fromCodePoint(0xe323);
    if (n.includes("keyboard"))
      return String.fromCodePoint(0xe312);
    if (n.includes("phone"))
      return String.fromCodePoint(0xe7ba);
    if (n.includes("watch"))
      return String.fromCodePoint(0xe334);
    return root.bluetooth;
  }

  // An icon URL for a desktop entry's Icon= value, or "" if absent. That can be
  // a theme name, a name only found in the pixmaps folders, or a full path.
  function themeIcon(name) {
    if (!name)
      return "";
    if (name.startsWith("/"))
      return "file://" + name;
    if (Quickshell.hasThemeIcon(name))
      return Quickshell.iconPath(name);
    return root.pixmaps[name] ? "file://" + root.pixmaps[name] : "";
  }

  // Maps a Hyprland window class to a glyph. Matching is substring-based and
  // case-insensitive, so "org.mozilla.firefox" still finds "firefox".
  function forClass(cls) {
    if (!cls)
      return root.appGeneric;
    const c = cls.toLowerCase();
    const table = [[["alacritty", "kitty", "foot", "wezterm", "konsole", "terminal"], root.appTerminal], [["firefox", "chrom", "zen", "brave", "librewolf", "vivaldi"], root.appBrowser], [["code", "nvim", "vim", "emacs", "zed", "jetbrains", "qtcreator"], root.appEditor], [["dolphin", "nautilus", "thunar", "nemo", "files"], root.appFiles], [["discord", "telegram", "signal", "element", "slack"], root.appChat], [["spotify", "mpv", "vlc", "audacious"], root.music], [["settings", "control", "pavucontrol", "systemsettings"], root.appSettings]];
    for (const [keys, glyph] of table) {
      for (const k of keys) {
        if (c.includes(k))
          return glyph;
      }
    }
    return root.appGeneric;
  }
}
