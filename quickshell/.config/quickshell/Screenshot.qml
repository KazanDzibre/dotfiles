// Screenshot.qml — capture state machine.
//
// There is no grim/slurp on this system, so the whole thing is built on
// ScreencopyView: the overlay freezes a frame of the screen, you drag a
// rectangle over it, and the frozen frame is grabbed and cropped.
//
// The crop runs through ImageMagick, which is already a dependency of the
// wallpaper thumbnailer.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"

  // "" when idle; "region" or "screen" while the overlay is up.
  property string mode: ""
  readonly property bool active: mode !== ""

  property string lastPath: ""

  function region() {
    root.mode = "region";
  }

  function fullScreen() {
    root.mode = "screen";
  }

  function cancel() {
    root.mode = "";
  }

  Process {
    id: processor
  }

  // Called by the overlay once it has written the full-resolution frame to
  // `source`. Crop values are in physical pixels.
  function finish(source, x, y, width, height) {
    root.mode = "";

    if (width < 2 || height < 2) {
      // A stray click rather than a drag — nothing worth saving.
      processor.command = ["rm", "-f", source];
      processor.startDetached();
      return;
    }

    const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
    const target = root.saveDir + "/" + stamp + ".png";
    root.lastPath = target;

    const crop = Math.round(width) + "x" + Math.round(height) + "+" + Math.round(x) + "+" + Math.round(y);

    // Crop, put it on the clipboard, bin the temp frame, then tell the user via
    // the notification server this shell now owns.
    const script = "mkdir -p " + root.saveDir + " && " + "magick \"$1\" -crop " + crop + " +repage \"$2\" && " + "wl-copy --type image/png < \"$2\"; " + "rm -f \"$1\"; " + "notify-send -a Screenshot -i \"$2\" 'Screenshot saved' \"$(basename \"$2\") — copied to clipboard\"";

    processor.command = ["sh", "-c", script, "sh", source, target];
    processor.startDetached();
  }
}
