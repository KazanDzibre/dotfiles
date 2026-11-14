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

  // Called by the overlay once it has written the frozen frame to `source`.
  // The selection is in fractions of the frame (0–1), the output size in the
  // screen's real pixels.
  function finish(source, fx, fy, fw, fh, outW, outH) {
    root.mode = "";

    if (outW < 2 || outH < 2) {
      // A stray click rather than a drag — nothing worth saving.
      processor.command = ["rm", "-f", source];
      processor.startDetached();
      return;
    }

    const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
    const target = root.saveDir + "/" + stamp + ".png";
    root.lastPath = target;

    // Measure the frame, cut the fraction out of it, and size it to real
    // pixels; then clipboard, bin the temp frame, notify.
    const script = "mkdir -p " + root.saveDir + " && " +
      "set -- \"$1\" \"$2\" $(magick identify -format '%w %h' \"$1\") && " +
      "crop=$(awk -v W=$3 -v H=$4 'BEGIN { printf \"%dx%d+%d+%d\", W*" + fw + "+0.5, H*" + fh + "+0.5, W*" + fx + "+0.5, H*" + fy + "+0.5 }') && " +
      "magick \"$1\" -crop $crop +repage -resize " + outW + "x" + outH + "! \"$2\" && " +
      "wl-copy --type image/png < \"$2\"; " + "rm -f \"$1\"; " +
      "notify-send -a Screenshot -i \"$2\" 'Screenshot saved' \"$(basename \"$2\") — copied to clipboard\"";

    processor.command = ["sh", "-c", script, "sh", source, target];
    processor.startDetached();
  }
}
