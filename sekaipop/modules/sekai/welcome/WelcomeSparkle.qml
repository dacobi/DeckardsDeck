import QtQuick
import QtQuick.Shapes

// Angular cyberpunk targeting reticle / diamond crosshair for the welcome logo:
// sharp geometric diamond with technical crosshair ticks, dark bezel, bright fill.
// `pop` (0..1+) scales the reticle so spring overshoot hops past 1.
Item {
    id: root

    property real size: 40
    property color fill: "#00f0ff"
    property color ink: "#05070d"
    property real stroke: Math.max(1.6, root.size * 0.075)
    property real pop: 1
    // 0..1: a slow pulse, driven from outside while the logo idles.
    property real twinkle: 0

    width: root.size
    height: root.size
    visible: root.pop > 0.001
    transformOrigin: Item.Center
    scale: Math.max(0, root.pop) * (1 + 0.05 * root.twinkle)
    rotation: 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Outer crosshair ticks
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke * 1.4
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathMove { x: root.width / 2; y: 0 }
            PathLine { x: root.width / 2; y: root.height }
            PathMove { x: 0; y: root.height / 2 }
            PathLine { x: root.width; y: root.height / 2 }
        }

        // Sharp angular diamond core
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke
            fillColor: root.fill
            joinStyle: ShapePath.MiterJoin
            startX: root.width / 2
            startY: root.height * 0.16

            PathLine { x: root.width * 0.84; y: root.height / 2 }
            PathLine { x: root.width / 2; y: root.height * 0.84 }
            PathLine { x: root.width * 0.16; y: root.height / 2 }
            PathLine { x: root.width / 2; y: root.height * 0.16 }
        }
    }
}
