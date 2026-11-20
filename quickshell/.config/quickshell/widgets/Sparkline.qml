// Sparkline.qml — intraday shape for a quote.
//
// Canvas rather than a Row of rectangles: a line reads as a trend at this size,
// bars read as noise. Under the line a soft fill in its colour fades to nothing,
// and the latest value gets a dot with a faint ring. The line draws itself in
// from the left whenever it first shows or its data changes.
import QtQuick
import qs

Canvas {
  id: root

  property var points: []
  property color stroke: Theme.accent
  // 0..1: how much of the line is drawn so far.
  property real progress: 1
  // Room for the end dot and its ring at the edges.
  readonly property real inset: 4

  onPointsChanged: {
    root.requestPaint();
    if (root.visible && root.points && root.points.length > 1)
      draw.restart();
  }
  onStrokeChanged: requestPaint()
  onProgressChanged: requestPaint()
  onVisibleChanged: {
    if (root.visible && root.points && root.points.length > 1)
      draw.restart();
  }

  NumberAnimation {
    id: draw
    target: root
    property: "progress"
    from: 0
    to: 1
    duration: Theme.motionBase + 120
    easing.type: Easing.OutCubic
  }

  function rgba(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
  }

  onPaint: {
    const ctx = getContext("2d");
    ctx.reset();

    if (!points || points.length < 2)
      return;

    let min = points[0];
    let max = points[0];
    for (const value of points) {
      if (value < min)
        min = value;
      if (value > max)
        max = value;
    }
    // A dead-flat series would divide by zero; draw it down the middle instead.
    const range = max - min || 1;
    const flat = max === min;

    const left = root.inset, right = width - root.inset;
    const top = root.inset, bottom = height - root.inset;
    const xs = [], ys = [];
    for (let i = 0; i < points.length; i++) {
      xs.push(left + i / (points.length - 1) * (right - left));
      ys.push(flat ? height / 2 : bottom - (points[i] - min) / range * (bottom - top));
    }

    // How far along the line we are: whole segments, then a fraction of one.
    const reach = progress * (points.length - 1);
    const whole = Math.min(points.length - 1, Math.floor(reach));
    const part = reach - whole;
    const tx = whole >= points.length - 1 ? xs[whole] : xs[whole] + (xs[whole + 1] - xs[whole]) * part;
    const ty = whole >= points.length - 1 ? ys[whole] : ys[whole] + (ys[whole + 1] - ys[whole]) * part;

    // The line's path so far.
    const trace = () => {
      ctx.moveTo(xs[0], ys[0]);
      for (let i = 1; i <= whole; i++)
        ctx.lineTo(xs[i], ys[i]);
      if (whole < points.length - 1)
        ctx.lineTo(tx, ty);
    };

    // Fill: down to the baseline, fading out.
    const fill = ctx.createLinearGradient(0, top, 0, height);
    fill.addColorStop(0, root.rgba(root.stroke, 0.28));
    fill.addColorStop(1, root.rgba(root.stroke, 0));
    ctx.beginPath();
    trace();
    ctx.lineTo(tx, height);
    ctx.lineTo(xs[0], height);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();

    ctx.beginPath();
    trace();
    ctx.strokeStyle = root.stroke;
    ctx.lineWidth = 1.5;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.stroke();

    // The tip: a ring, then the dot.
    ctx.beginPath();
    ctx.arc(tx, ty, 3.6, 0, Math.PI * 2);
    ctx.fillStyle = root.rgba(root.stroke, 0.25);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(tx, ty, 1.9, 0, Math.PI * 2);
    ctx.fillStyle = root.stroke;
    ctx.fill();
  }
}
