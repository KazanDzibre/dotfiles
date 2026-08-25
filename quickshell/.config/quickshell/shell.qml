import Quickshell
import qs.widgets

ShellRoot {
  Bar {}

  // Its own layer-shell window rather than part of the bar: toasts have to
  // appear without anything being clicked.
  NotificationToasts {}

  // Fullscreen, and only mapped while a capture is in progress.
  ScreenshotOverlay {}

  // Left-edge drawers. Both native, so both slide from the edge they live on.
  DashboardPanel {}

  AiChatPanel {}
}
