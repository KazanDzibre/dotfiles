// Sparkline.qml — intraday shape for a quote.
//
// Canvas rather than a Row of rectangles: a line reads as a trend at this size,
// bars read as noise.
import QtQuick
import qs

Canvas {
  id: root

  property var points: []
  property color stroke: Theme.accent

  onPointsChanged: requestPaint()
  onStrokeChanged: requestPaint()

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

    ctx.beginPath();
    for (let i = 0; i < points.length; i++) {
      const px = i / (points.length - 1) * width;
      const py = flat ? height / 2 : height - (points[i] - min) / range * height;
      if (i === 0)
        ctx.moveTo(px, py);
      else
        ctx.lineTo(px, py);
    }

    ctx.strokeStyle = root.stroke;
    ctx.lineWidth = 1.5;
    ctx.lineJoin = "round";
    ctx.stroke();
  }
}
