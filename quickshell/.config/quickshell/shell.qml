import Quickshell
import qs.widgets

ShellRoot {
  Bar {}

  // Notifications pop out of the bar's island now (Moments.qml), so the corner
  // toasts are off. Put this back to have both.
  // NotificationToasts {}

  // Fullscreen, and only mapped while a capture is in progress.
  ScreenshotOverlay {}

  // Left-edge drawers. Both native, so both slide from the edge they live on.
  DashboardPanel {}

  AiChatPanel {}

  // One per screen, just above the wallpaper; only mapped while a newly
  // applied wallpaper grows in from the middle.
  WallpaperReveal {}
}
