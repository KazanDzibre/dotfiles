import Quickshell
import qs.widgets

ShellRoot {
  Bar {}

  // Its own layer-shell window rather than part of the bar: toasts have to
  // appear without anything being clicked.
  NotificationToasts {}
}
