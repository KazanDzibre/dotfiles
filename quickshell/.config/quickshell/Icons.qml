// Icons.qml — Nerd Font glyphs, addressed by codepoint rather than pasted in
// literally so they survive copy/paste and are greppable against the Nerd Font
// cheat sheet. All of these are Material Design Icons (nf-md-*).
pragma Singleton

import Quickshell

Singleton {
  id: root

  // ------------------------------------------------------------------ audio
  readonly property string volHigh: String.fromCodePoint(0xf057e)
  readonly property string volMed: String.fromCodePoint(0xf0580)
  readonly property string volLow: String.fromCodePoint(0xf057f)
  readonly property string volMute: String.fromCodePoint(0xf075f)

  // ---------------------------------------------------------------- battery
  // Index 0..10 maps to 0%..100% in ten-point steps.
  readonly property var batteryRamp: [String.fromCodePoint(0xf008e)  // outline / empty
    , String.fromCodePoint(0xf007a), String.fromCodePoint(0xf007b), String.fromCodePoint(0xf007c), String.fromCodePoint(0xf007d), String.fromCodePoint(0xf007e), String.fromCodePoint(0xf007f), String.fromCodePoint(0xf0080), String.fromCodePoint(0xf0081), String.fromCodePoint(0xf0082), String.fromCodePoint(0xf0079)  // full
  ]
  readonly property string batteryCharging: String.fromCodePoint(0xf0084)
  readonly property string batteryAlert: String.fromCodePoint(0xf0083)
  readonly property string batteryUnknown: String.fromCodePoint(0xf0091)
  readonly property string powerPlug: String.fromCodePoint(0xf06a5)

  // ---------------------------------------------------------------- network
  readonly property var wifiRamp: [String.fromCodePoint(0xf092f)  // no signal
    , String.fromCodePoint(0xf091f), String.fromCodePoint(0xf0922), String.fromCodePoint(0xf0925), String.fromCodePoint(0xf0928)  // full
  ]
  readonly property string wifiOff: String.fromCodePoint(0xf05aa)
  readonly property string ethernet: String.fromCodePoint(0xf0200)
  readonly property string noNetwork: String.fromCodePoint(0xf0c9c)

  // ------------------------------------------------------------------ media
  readonly property string play: String.fromCodePoint(0xf040a)
  readonly property string pause: String.fromCodePoint(0xf03e4)
  readonly property string next: String.fromCodePoint(0xf04ad)
  readonly property string prev: String.fromCodePoint(0xf04ae)
  readonly property string music: String.fromCodePoint(0xf075a)
  readonly property string musicNote: String.fromCodePoint(0xf0387)
  readonly property string album: String.fromCodePoint(0xf0025)
  readonly property string repeatAll: String.fromCodePoint(0xf0456)
  readonly property string repeatOne: String.fromCodePoint(0xf0458)
  readonly property string repeatOff: String.fromCodePoint(0xf0457)
  readonly property string shuffleOff: String.fromCodePoint(0xf049e)

  // -------------------------------------------------------------- calendar
  readonly property string calendar: String.fromCodePoint(0xf00ed)
  readonly property string chevronLeft: String.fromCodePoint(0xf0141)
  readonly property string chevronRight: String.fromCodePoint(0xf0142)

  // -------------------------------------------------------------- dashboard
  readonly property string dashboard: String.fromCodePoint(0xf1489)
  readonly property string chart: String.fromCodePoint(0xf012a)
  readonly property string newspaper: String.fromCodePoint(0xf1004)
  readonly property string devFeed: String.fromCodePoint(0xf0174)   // md-code_tags
  readonly property string trendUp: String.fromCodePoint(0xf0535)
  readonly property string trendDown: String.fromCodePoint(0xf0533)
  readonly property string openExternal: String.fromCodePoint(0xf03cc)

  // ------------------------------------------------------------------ tools
  readonly property string camera: String.fromCodePoint(0xf0100)
  readonly property string crop: String.fromCodePoint(0xf019e)
  readonly property string monitorShot: String.fromCodePoint(0xf0e51)
  readonly property string clipboard: String.fromCodePoint(0xf0a38)
  readonly property string copy: String.fromCodePoint(0xf018f)
  readonly property string search: String.fromCodePoint(0xf0349)
  readonly property string coffee: String.fromCodePoint(0xf0176)
  readonly property string coffeeOff: String.fromCodePoint(0xf06ca)

  // ---------------------------------------------------------- notifications
  readonly property string bell: String.fromCodePoint(0xf009a)
  readonly property string bellOutline: String.fromCodePoint(0xf009c)
  readonly property string bellOff: String.fromCodePoint(0xf009b)
  readonly property string bellBadge: String.fromCodePoint(0xf116b)
  readonly property string clearAll: String.fromCodePoint(0xf039f)

  // ------------------------------------------------------------------- tray
  readonly property string chip: String.fromCodePoint(0xf061a)

  // ------------------------------------------------------------ ai assistant
  readonly property string ai: String.fromCodePoint(0xf06a9)
  readonly property string send: String.fromCodePoint(0xf048a)
  readonly property string plus: String.fromCodePoint(0xf0415)
  readonly property string web: String.fromCodePoint(0xf059f)
  readonly property string key: String.fromCodePoint(0xf0dd6)
  readonly property string stop: String.fromCodePoint(0xf04db)

  // ----------------------------------------------------------------- display
  readonly property string brightness: String.fromCodePoint(0xf00df)
  readonly property string brightnessLow: String.fromCodePoint(0xf00de)
  readonly property string warmth: String.fromCodePoint(0xf05a6)
  readonly property string alert: String.fromCodePoint(0xf002a)

  // ------------------------------------------------------------------ power
  readonly property string power: String.fromCodePoint(0xf0425)
  readonly property string logout: String.fromCodePoint(0xf0343)
  readonly property string restart: String.fromCodePoint(0xf0709)
  readonly property string sleep: String.fromCodePoint(0xf04b2)

  // -------------------------------------------------------------- bluetooth
  readonly property string bluetooth: String.fromCodePoint(0xf00af)
  readonly property string bluetoothOff: String.fromCodePoint(0xf00b2)
  readonly property string bluetoothConnected: String.fromCodePoint(0xf00b1)

  // ------------------------------------------------------------------ theme
  readonly property string sun: String.fromCodePoint(0xf0599)
  readonly property string moon: String.fromCodePoint(0xf0594)

  // ---------------------------------------------------------------- windows
  readonly property string windows: String.fromCodePoint(0xf05b2)
  readonly property string close: String.fromCodePoint(0xf0156)

  // ------------------------------------------------------------- wallpaper
  readonly property string wallpaper: String.fromCodePoint(0xf0e09)
  readonly property string shuffle: String.fromCodePoint(0xf049f)

  // ------------------------------------------------------------ system info
  readonly property string cpu: String.fromCodePoint(0xf0ee0)
  readonly property string memory: String.fromCodePoint(0xf035b)
  readonly property string disk: String.fromCodePoint(0xf02ca)

  // --------------------------------------------------------------- updates
  readonly property string updates: String.fromCodePoint(0xf03d6)
  readonly property string upToDate: String.fromCodePoint(0xf05e1)
  readonly property string refresh: String.fromCodePoint(0xf0450)
  readonly property string download: String.fromCodePoint(0xf01da)

  // -------------------------------------------------------------- interface
  readonly property string forget: String.fromCodePoint(0xf09e7)
  readonly property string check: String.fromCodePoint(0xf012c)
  readonly property string lock: String.fromCodePoint(0xf033e)
  readonly property string spinner: String.fromCodePoint(0xf0772)
  readonly property string eyeShow: String.fromCodePoint(0xf06d0)
  readonly property string eyeHide: String.fromCodePoint(0xf0209)
  readonly property string mic: String.fromCodePoint(0xf036c)
  readonly property string micOff: String.fromCodePoint(0xf036d)

  // ------------------------------------------------------------ app icons
  readonly property string appGeneric: String.fromCodePoint(0xf08c6)
  readonly property string appTerminal: String.fromCodePoint(0xf018d)
  readonly property string appBrowser: String.fromCodePoint(0xf059f)
  readonly property string appEditor: String.fromCodePoint(0xf0169)
  readonly property string appFiles: String.fromCodePoint(0xf024b)
  readonly property string appChat: String.fromCodePoint(0xf0361)
  readonly property string appSettings: String.fromCodePoint(0xf08bb)

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
    if (entry && entry.icon && Quickshell.hasThemeIcon(entry.icon))
      return Quickshell.iconPath(entry.icon);

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
      return String.fromCodePoint(0xf02cb);
    if (n.includes("speaker") || n.includes("audio"))
      return String.fromCodePoint(0xf04c3);
    if (n.includes("mouse"))
      return String.fromCodePoint(0xf037d);
    if (n.includes("keyboard"))
      return String.fromCodePoint(0xf030c);
    if (n.includes("phone"))
      return String.fromCodePoint(0xf011c);
    if (n.includes("watch"))
      return String.fromCodePoint(0xf0589);
    return root.bluetooth;
  }

  // A themed icon URL for any freedesktop icon name, or "" if absent.
  function themeIcon(name) {
    return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
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
