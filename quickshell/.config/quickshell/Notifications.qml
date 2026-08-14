// Notifications.qml — the shell IS the notification daemon.
//
// Instantiating NotificationServer claims org.freedesktop.Notifications on the
// session bus. Nothing else was serving it (dunst is installed but wasn't
// running), so notifications were going nowhere before this.
//
// Two audiences for the same data: transient toasts that slide in and expire,
// and a history panel you can open later. `tracked` is what keeps a
// notification alive after it has been shown.
pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: root

  property bool doNotDisturb: false

  // Currently on screen as toasts.
  property var toasts: []

  // Notifications carry no timestamp, so record arrival ourselves, keyed by id.
  property var arrivals: ({})

  // Newest first for the history panel.
  readonly property var history: server.trackedNotifications ? Array.from(server.trackedNotifications.values).reverse() : []
  readonly property int count: history.length

  NotificationServer {
    id: server

    // Survive a config reload — losing your notifications every time a file is
    // saved would be miserable.
    keepOnReload: true

    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true
    actionIconsSupported: true
    persistenceSupported: true

    onNotification: notification => {
      // Without this the notification is dropped the moment the signal returns.
      notification.tracked = true;

      const stamps = Object.assign({}, root.arrivals);
      stamps[notification.id] = Date.now();
      root.arrivals = stamps;

      // Do not disturb still records history, it just doesn't interrupt you —
      // except for anything marked critical.
      if (!root.doNotDisturb || notification.urgency === NotificationUrgency.Critical)
        root.pushToast(notification);
    }
  }

  function pushToast(notification) {
    const next = root.toasts.filter(t => t !== notification);
    next.push(notification);
    while (next.length > 4)
      next.shift();
    root.toasts = next;
  }

  function popToast(notification) {
    root.toasts = root.toasts.filter(t => t !== notification);
  }

  function dismiss(notification) {
    root.popToast(notification);
    notification.dismiss();
  }

  function clearAll() {
    // dismiss() mutates the model, so iterate a copy.
    for (const n of root.history.slice())
      n.dismiss();
    root.toasts = [];
  }

  // Relative age. Depends on Time.now so it re-renders every minute.
  function ageText(notification) {
    const stamp = root.arrivals[notification.id];
    if (!stamp)
      return "";
    const seconds = Math.max(0, (Time.now.getTime() - stamp) / 1000);
    if (seconds < 60)
      return "now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60)
      return minutes + "m";
    const hours = Math.floor(minutes / 60);
    if (hours < 24)
      return hours + "h";
    return Math.floor(hours / 24) + "d";
  }

  // An app icon if the notification named one, else its image, else nothing and
  // the widget falls back to a glyph.
  function iconFor(notification) {
    if (notification.image && notification.image.length > 0)
      return notification.image;
    if (notification.appIcon && notification.appIcon.length > 0) {
      const themed = Icons.themeIcon(notification.appIcon);
      if (themed.length > 0)
        return themed;
      // Some apps pass a path rather than an icon name.
      if (notification.appIcon.startsWith("/") || notification.appIcon.startsWith("file:"))
        return notification.appIcon;
    }
    return "";
  }

  function urgencyColor(notification) {
    if (notification.urgency === NotificationUrgency.Critical)
      return Theme.crit;
    if (notification.urgency === NotificationUrgency.Low)
      return Theme.fgDim;
    return Theme.accent;
  }
}
