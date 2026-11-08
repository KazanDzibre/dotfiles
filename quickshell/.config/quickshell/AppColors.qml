pragma Singleton

// AppColors.qml — one recognisable colour per app, taken from its icon, for the
// workspace dots. Icons with no real colour get a steady colour from their name.

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var known: ({})
  property var waiting: []
  property string looking: ""

  // Empty until the icon has been read; the dot just changes colour when it is.
  function colorFor(cls) {
    if (!cls)
      return "";
    const hex = root.known[cls];
    if (hex !== undefined)
      return hex;
    if (root.looking !== cls && !root.waiting.includes(cls)) {
      root.waiting.push(cls);
      Qt.callLater(root.next);
    }
    return "";
  }

  function next() {
    if (root.looking || root.waiting.length === 0)
      return;
    root.looking = root.waiting.shift();
    const entry = DesktopEntries.heuristicLookup(root.looking);
    const names = [entry ? entry.icon : "", root.looking, root.looking.toLowerCase(), root.looking.split(".").pop().toLowerCase()].filter(n => n);
    lookup.exec(["sh", "-c", root.script, "sh"].concat(names));
  }

  // Any app's own icon: the hicolor copy first, since themes often recolour.
  readonly property string script: [
    'for n in "$@"; do',
    '  case "$n" in /*) f=$n ;; *)',
    '    f=$(find -L "$HOME/.local/share/icons/hicolor" /usr/share/icons/hicolor /usr/share/pixmaps \\( -name "$n.png" -o -name "$n.svg" \\) 2>/dev/null | sort -V | tail -1)',
    '    [ -n "$f" ] || f=$(find -L /usr/share/icons \\( -name "$n.png" -o -name "$n.svg" \\) 2>/dev/null | sort -V | tail -1)',
    '  ;; esac',
    '  [ -f "$f" ] && exec magick -background none "$f" -resize 48x48 -colors 8 -unique-colors txt:-',
    'done'
  ].join("\n")

  // The same name always lands on the same hue.
  function fromName(cls) {
    let hash = 0;
    for (let i = 0; i < cls.length; i++)
      hash = (hash * 31 + cls.charCodeAt(i)) % 360;
    return Qt.hsva(hash / 360, 0.5, 0.92, 1).toString();
  }

  Process {
    id: lookup

    stdout: StdioCollector {
      onStreamFinished: {
        const next = Object.assign({}, root.known);
        next[root.looking] = Media.pickTint(text) || root.fromName(root.looking);
        root.known = next;
        root.looking = "";
        Qt.callLater(root.next);
      }
    }
  }
}
