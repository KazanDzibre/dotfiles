import Quickshell
import qs.widgets

ShellRoot {
  Bar {}

  // Fullscreen, and only mapped while a capture is in progress.
  ScreenshotOverlay {}

  // Left-edge drawer. Native, so it slides from the edge it lives on. (The
  // dashboard used to be one too; it is now a panel of the control center.)
  AiChatPanel {}

  // The wallpaper itself, drawn by the shell so it can slide with the
  // workspaces (hyprpaper still runs underneath as the fallback).
  ParallaxWallpaper {}

  // One per screen, just above the wallpaper; only mapped while a newly
  // applied wallpaper grows in from the middle.
  WallpaperReveal {}

  // The screen's four corners, rounded like everything on it.
  ScreenCorners {}
}
