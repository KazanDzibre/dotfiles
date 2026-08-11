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

  // -------------------------------------------------------------- calendar
  readonly property string calendar: String.fromCodePoint(0xf00ed)
  readonly property string chevronLeft: String.fromCodePoint(0xf0141)
  readonly property string chevronRight: String.fromCodePoint(0xf0142)

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
