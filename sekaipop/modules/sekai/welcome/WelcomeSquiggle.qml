import QtQuick
import QtQuick.Shapes

// An angular cyberpunk telemetry circuit trace line, drawn on from its left end:
// a dark outline stroke with a bright trace on top, using 45-degree step knees.
// `draw` (0..1) is how much of it exists, from its left end.
//
//   WelcomeSquiggle { length: 60; draw: 0.5 }
Item {
    id: root

    property real length: 60
    property real amplitude: 5
    property real cycles: 2
    property real stroke: 3
    property real draw: 1
    property color fill: "#ffefce"
    property color ink: "#232235"

    readonly property var knots: [
        Qt.point(0.00,  root.amplitude * 0.8),
        Qt.point(0.28,  root.amplitude * 0.8),
        Qt.point(0.38, -root.amplitude * 0.8),
        Qt.point(0.68, -root.amplitude * 0.8),
        Qt.point(0.78,  0.0),
        Qt.point(1.00,  0.0)
    ]

    readonly property var pts: {
        const a = [];
        const k = root.knots;
        const segs = k.length - 1;
        const u = Math.max(0, Math.min(1, root.draw)) * segs;
        const last = Math.floor(u);
        for (let i = 0; i <= last && i < k.length; i++)
            a.push(Qt.point(root.length * k[i].x, k[i].y));
        const f = u - last;
        if (f > 0.001 && last < segs) {
            const p0 = k[last];
            const p1 = k[last + 1];
            a.push(Qt.point(root.length * (p0.x + (p1.x - p0.x) * f), p0.y + (p1.y - p0.y) * f));
        }
        return a;
    }

    width: root.length
    height: root.amplitude * 2
    visible: root.draw > 0.01 && root.pts.length > 1

    Shape {
        x: 0
        y: root.amplitude
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke * 2.5
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathPolyline { path: root.pts }
        }

        ShapePath {
            strokeColor: root.fill
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathPolyline { path: root.pts }
        }
    }
}
