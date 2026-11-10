import Quickshell
import qs.widgets

ShellRoot {
  Bar {}

  // Notifications pop out of the bar's island now (Moments.qml), so the corner
  // toasts are off. Put this back to have both.
  // NotificationToasts {}

  // Fullscreen, and only mapped while a capture is in progress.
  ScreenshotOverlay {}

  // Left-edge drawer. Native, so it slides from the edge it lives on. (The
  // dashboard used to be one too; it is now a panel of the control center.)
  AiChatPanel {}

  // One per screen, just above the wallpaper; only mapped while a newly
  // applied wallpaper grows in from the middle.
  WallpaperReveal {}
}
