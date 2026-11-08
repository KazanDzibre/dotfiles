// Pulse.qml — a tiny live graph for the status pill: CPU in amber, network in
// the accent colour. Only there while the machine is properly busy.
import QtQuick
import qs

Canvas {
  id: root

  implicitWidth: 40
  implicitHeight: 14

  // Fades before leaving, so the pill only shrinks once the graph has gone.
  readonly property bool on: SysInfo.busy
  opacity: on ? 1 : 0
  visible: on || opacity > 0.01

  Behavior on opacity {
    NumberAnimation {
      duration: 240
    }
  }

  Connections {
    target: SysInfo

    function onCpuHistoryChanged() {
      if (root.visible)
        root.requestPaint();
    }
  }

  onVisibleChanged: if (visible)
    requestPaint()

  function draw(ctx, values, ceiling, color) {
    if (values.length < 2)
      return;
    const step = width / (SysInfo.historyLength - 1);
    const left = width - step * (values.length - 1);
    const y = v => height - 1 - Math.min(1, v / ceiling) * (height - 2);

    ctx.beginPath();
    values.forEach((v, i) => {
      if (i === 0)
        ctx.moveTo(left, y(v));
      else
        ctx.lineTo(left + i * step, y(v));
    });
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.4;
    ctx.lineJoin = "round";
    ctx.stroke();

    ctx.lineTo(width, height);
    ctx.lineTo(left, height);
    ctx.closePath();
    ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.16);
    ctx.fill();
  }

  onPaint: {
    const ctx = getContext("2d");
    ctx.reset();
    // Network has no natural top, so it's scaled to the recent peak.
    draw(ctx, SysInfo.netHistory, Math.max(3000000, ...SysInfo.netHistory), Theme.accent);
    draw(ctx, SysInfo.cpuHistory, 1, Theme.warn);
  }
}
