import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.modules.common

// Shared building block: a thick navy outline with a white "ring"
// gap between the outline and the actual colored fill, sitting on a
// flat offset "hard" shadow. Confirmed straight from the current
// Figma file — every pill in the bar uses this exact three-layer
// structure (outline -> white ring -> color), just with different
// ring widths (8px is the default everywhere except Media, which
// uses 5px). Set fillColor for a flat fill or fillGradient for the
// cyan/mint gradient pills; the ring itself is plain white unless a
// caller sets ringColorTop/ringColorBottom (the dock's hover/running
// glow — see Dock.qml). Anything declared inside a Pill lands on top
// of the fill.
//
// Inside a bar drawn in the Capsule style (see `capsule` below) all of that is
// dropped: the pill is one flat, fully rounded chip with no outline, ring or shadow.
// On a flat bar it is Theme.capChipHeight tall and centred in whatever box the caller
// gave it; on a standing bar (`capsuleV`) it is the whole box (less the shadow's room at
// the bottom), so the two-line texts have room.
//
// A popup card that hangs off a Capsule bar is not inside the bar, so it cannot
// find `capsuleBar` up the tree. Its owner (SekaiPopup, TrayPopups) sets
// `capRim` instead: the card keeps its own shape but takes the bar's colours --
// outline = the bar's rim, hard shadow = the bar's shadow, ring and fill = the
// bar's body.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // Inside the Capsule bar (Theme.capsuleFor): draw as a flat chip instead.
    readonly property bool capsule: mt.capsuleFor(root)
    // ...on a bar standing on the left / right edge.
    readonly property bool capsuleV: root.capsule && mt.capsuleVerticalFor(root)
    // The width of a pill on a standing bar: the Capsule bar's chips are narrower.
    readonly property real barVWidth: root.capsule ? mt.capVChip : mt.barVPillWidth
    // A chip normally takes the capsule's chip colour. A pill whose colour means
    // something (a Discord call, the mic in use, updates waiting) sets this to keep
    // its own fillColor there.
    property bool capKeepsFill: false
    // A popup card under a Capsule bar: outline, shadow, ring and fill in the
    // bar's rim / shadow / body colours (Theme.capRim / capShade / capBody).
    property bool capRim: false
    // No background at all: no hard shadow, outline, ring or fill. Whatever is
    // declared inside the Pill is still drawn, and the Pill keeps its size, so
    // nothing round it moves. The dock's Transparent style (Dock.qml).
    property bool bare: false
    // No hard shadow: the cap sits flat (a press only dips it 1 px). The pill keeps
    // its size, so the room the shadow took stays empty. The dock's Capsule keys.
    property bool flat: false

    // Inside the Quick Panel / To-Do in the first dark mode: the classic look.
    readonly property bool classicScope: mt.classicFor(root)

    property color fillColor: classicScope ? mt.pSurface : mt.surface
    property Gradient fillGradient: null
    property real cornerRadius: height / 2
    readonly property real effectiveRadius: mt.edgy
        ? Math.min(root.cornerRadius, (root.width >= 160 && root.height >= 50) ? mt.radiusOuter : mt.radiusInner)
        : root.cornerRadius
    property real ringWidth: mt.edgy ? (mt.borderWidth + mt.whiteLine) : 8

    // A ring drawn over the outer edge of the fill (inside, so the pill does
    // not grow), for the flat cards whose ringWidth equals their outline and
    // so show no ring of their own. 0 = none. Cards pass Theme.cardRing.
    property real innerRing: 0

    // Outline thickness, and where the hard shadow sits. The bar's pills
    // only ever drop it straight down (shadowDy 4, shadowDx 0); the Quick
    // Panel's buttons cast it down-right and change all three between
    // their OFF and ON looks, which is why they're properties here.
    property real borderWidth: mt.borderWidth
    property real shadowDx: 0
    property real shadowDy: mt.shadowOffset

    // Ring color, as the top/bottom stops of a vertical gradient. Both
    // default to plain white, so every existing Pill (badges, QuickToggle,
    // the launcher's search pill) looks exactly like it always has — set
    // these when a Pill's *ring* itself needs to carry color, like the
    // dock's hover/running glow (see Dock.qml), rather than just its fill.
    property color ringColorTop: classicScope ? mt.pRingWhite : mt.ringWhite
    property color ringColorBottom: classicScope ? mt.pRingWhite : mt.ringWhite

    // The raised part of the pill — the size without its shadow.
    readonly property real capWidth: width - shadowDx
    readonly property real capHeight: height - shadowDy
    default property alias content: fill.data

    // Physical-button press state. Pill itself never listens for
    // clicks (callers each have their own MouseArea, with their own
    // hit-test shape) — bind this to that MouseArea's own "pressed"
    // so the cap below reacts to the real press/release, not just a
    // completed click.
    property bool pressed: false

    implicitHeight: mt.pillHeight + shadowDy

    // Cyberpunk HUD polygon geometry parameters (used when mt.edgy is true).
    readonly property bool isHudCard: root.width >= 160 && root.height >= 54
    readonly property bool isHudKey: !root.isHudCard && (root.width >= 44 || root.height >= 26)
    readonly property real cutTR: root.isHudCard ? 14 : (root.isHudKey ? 6 : 3.5)
    readonly property real cutBL: root.isHudCard ? 12 : (root.isHudKey ? 5 : 3)
    readonly property real notchW: root.isHudCard ? Math.min(64, Math.round(root.capWidth * 0.24)) : 0
    readonly property real notchH: root.isHudCard ? 4 : 0

    // Fixed hard shadow — never moves. It's what the cap below either
    // reveals (raised) or fully covers (pressed).
    Rectangle {
        visible: !mt.edgy && !root.capsule && !root.bare && !root.flat
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight
        radius: root.effectiveRadius
        color: root.capRim ? mt.capShade
            : (root.classicScope ? mt.pLineShadow : mt.lineShadow)
        antialiasing: true
    }

    // Cyberpunk 2077 chamfered wireframe ghost shadow (when mt.edgy is true).
    Shape {
        id: hudShadow
        visible: mt.edgy && !root.capsule && !root.bare && !root.flat && root.capWidth > 4 && root.capHeight > 4
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight

        ShapePath {
            strokeWidth: 1.2
            strokeColor: root.capRim ? mt.capShade
                : Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, mt.dark ? 0.52 : 0.38)
            fillColor: Qt.rgba(0.02, 0.02, 0.05, mt.dark ? 0.78 : 0.28)
            startX: 0
            startY: 0
            PathLine { x: Math.max(0, hudShadow.width - root.cutTR); y: 0 }
            PathLine { x: hudShadow.width; y: Math.min(hudShadow.height, root.cutTR) }
            PathLine { x: hudShadow.width; y: hudShadow.height }
            PathLine { x: Math.max(root.cutBL, hudShadow.width - root.notchW); y: hudShadow.height }
            PathLine { x: Math.max(root.cutBL, hudShadow.width - root.notchW - root.notchH); y: hudShadow.height - root.notchH }
            PathLine { x: root.cutBL; y: hudShadow.height - root.notchH }
            PathLine { x: 0; y: Math.max(0, hudShadow.height - root.notchH - root.cutBL) }
            PathLine { x: 0; y: 0 }
        }
    }

    // The "cap" — outline, white ring, colored fill, and anything a
    // caller declares inside this Pill (it all ends up inside "fill"
    // below, so it rides along) — moves as one unit. Resting, it sits
    // at y:0 with the shadow peeking out beneath by shadowOffset,
    // reading as raised. Pressed, it drops onto the shadow (y:
    // shadowOffset), exactly covering it so the offset disappears —
    // the button looks pushed flush into the surface. Releasing lets
    // it spring back past rest and settle, like a real keycap
    // popping back up.
    Item {
        id: surface
        // Capsule: the whole box wide, one chip tall, in the middle of it; a press
        // only dips it 1 px (there is no shadow to sink into).
        x: root.capsule ? 0 : (root.pressed && !root.flat ? root.shadowDx : 0)
        y: root.capsule ? (root.capsuleV ? 0 : (root.height - surface.height) / 2) + (root.pressed ? 1 : 0)
                        : (root.pressed ? (root.flat ? 1 : root.shadowDy) : 0)
        width: root.capsule ? root.width : root.capWidth
        height: root.capsule ? (root.capsuleV ? Math.max(0, root.height - root.shadowDy)
                                              : Math.min(root.height, mt.capChipHeight))
                             : root.capHeight

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            id: face
            visible: !mt.edgy && !root.capsule && !root.bare
            anchors.fill: parent
            radius: root.effectiveRadius
            border.width: root.borderWidth
            border.color: root.capRim ? mt.capRim
                : (root.classicScope ? mt.pLine : mt.line)
            antialiasing: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.capRim ? mt.capBody : root.ringColorTop
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                GradientStop {
                    position: 1.0
                    color: root.capRim ? mt.capBody : root.ringColorBottom
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        // Cyberpunk 2077 45° chamfered HUD polygon body (when mt.edgy is true).
        Shape {
            id: hudFace
            visible: mt.edgy && !root.capsule && !root.bare && surface.width > 4 && surface.height > 4
            anchors.fill: parent

            readonly property color baseFill: root.capRim ? mt.capBody
                : (root.isHudCard && root.fillColor === mt.surface ? mt.hudSurface : root.fillColor)
            readonly property color strokeCol: root.capRim ? mt.capRim
                : (root.fillGradient !== null ? mt.accentYellow
                    : (root.isHudCard ? mt.accentFrame : mt.accentCyan))
            readonly property color gradStart: (root.fillGradient && root.fillGradient.stops.length > 0)
                ? root.fillGradient.stops[0].color : hudFace.baseFill
            readonly property color gradEnd: (root.fillGradient && root.fillGradient.stops.length > 0)
                ? root.fillGradient.stops[root.fillGradient.stops.length - 1].color : hudFace.baseFill

            ShapePath {
                strokeWidth: root.isHudCard ? 1.6 : 1.3
                strokeColor: hudFace.strokeCol
                fillColor: root.fillGradient ? "transparent" : hudFace.baseFill
                fillGradient: root.fillGradient ? hudGrad : null
                startX: 0
                startY: 0
                PathLine { x: Math.max(0, hudFace.width - root.cutTR); y: 0 }
                PathLine { x: hudFace.width; y: Math.min(hudFace.height, root.cutTR) }
                PathLine { x: hudFace.width; y: hudFace.height }
                PathLine { x: Math.max(root.cutBL, hudFace.width - root.notchW); y: hudFace.height }
                PathLine { x: Math.max(root.cutBL, hudFace.width - root.notchW - root.notchH); y: hudFace.height - root.notchH }
                PathLine { x: root.cutBL; y: hudFace.height - root.notchH }
                PathLine { x: 0; y: Math.max(0, hudFace.height - root.notchH - root.cutBL) }
                PathLine { x: 0; y: 0 }
            }

            LinearGradient {
                id: hudGrad
                x1: 0
                y1: 0
                x2: hudFace.width
                y2: hudFace.height
                GradientStop { position: 0.0; color: hudFace.gradStart }
                GradientStop { position: 1.0; color: hudFace.gradEnd }
            }
        }

        Rectangle {
            id: fill
            anchors.fill: face
            anchors.margins: root.capsule ? 0 : root.ringWidth
            radius: root.capsule ? (mt.edgy ? mt.radiusInner : Math.min(width, height) / 2) : Math.max(0, root.effectiveRadius - root.ringWidth)
            color: (root.bare || (mt.edgy && !root.capsule)) ? "transparent"
                : (root.capsule
                    ? (root.capKeepsFill ? root.fillColor : mt.capChip)
                    : (root.capRim ? mt.capBody
                        : (root.fillGradient ? "transparent" : root.fillColor)))
            gradient: (root.capsule || root.capRim || root.bare || mt.edgy) ? null : root.fillGradient

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            antialiasing: true
        }

        // Cyberpunk 2077 HUD multi-hue accents, edge bars, reticle grid & telemetry markers.
        Item {
            id: hudCorners
            anchors.fill: parent
            visible: mt.edgy && !root.capsule && !root.bare && parent.width >= 28 && parent.height >= 18

            // Left vertical high-voltage callout bar (Acid Yellow on cards & normal keys, Red on gradient keys)
            Rectangle {
                x: 0
                y: 0
                width: root.isHudCard ? 3.5 : 2.5
                height: Math.max(6, parent.height - root.cutBL - root.notchH - 2)
                color: root.fillGradient !== null ? mt.accentFrame
                    : (root.isHudCard ? mt.accentYellow : (root.isHudKey ? mt.accentYellow : mt.accentCyan))
                opacity: 0.92
            }

            // Card-level Anna Kuzminska HUD overlays (+ reticle grid, top cyan trace, bottom >>>> chevrons & serial)
            Item {
                anchors.fill: parent
                visible: root.isHudCard

                CyberStripe {
                    anchors.fill: parent
                    anchors.margins: 8
                    mode: "grid"
                    gridStep: 32
                    crossSize: 2.5
                    color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, mt.dark ? 0.08 : 0.06)
                }

                // Top-left cyan/yellow stepped telemetry bar
                Rectangle {
                    x: 4
                    y: 0
                    width: Math.min(52, parent.width * 0.22)
                    height: 2.5
                    color: mt.accentCyan
                }

                // Top-right corner status dot inside the 45° chamfer
                Rectangle {
                    x: parent.width - root.cutTR - 8
                    y: 4
                    width: 4
                    height: 4
                    color: mt.accentYellow
                }

                // Stepped bottom-right notch highlight bar in Cyan + Green status tick
                Rectangle {
                    x: Math.max(root.cutBL + 8, parent.width - root.notchW)
                    y: parent.height - 2
                    width: Math.max(0, root.notchW - 14)
                    height: 2
                    color: mt.accentCyan
                }

                Rectangle {
                    x: parent.width - 10
                    y: parent.height - 2
                    width: 6
                    height: 2
                    color: mt.accentGreen
                }

                // Micro-telemetry serial number in bottom-left notch step
                Text {
                    x: root.cutBL + 6
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.notchH + 1
                    visible: parent.width >= 220 && parent.height >= 90
                    text: "382 248 40270274 // HUD"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 7
                    font.weight: Font.Bold
                    font.letterSpacing: 1.1
                    color: Qt.rgba(mt.accentAmber.r, mt.accentAmber.g, mt.accentAmber.b, 0.68)
                }
            }
        }

        // Above the fill and everything declared inside the Pill.
        Rectangle {
            anchors.fill: fill
            radius: fill.radius
            color: "transparent"
            border.width: root.innerRing
            border.color: root.capRim ? mt.capBody : root.ringColorTop
            visible: !mt.edgy && root.innerRing > 0 && !root.capsule && !root.bare
            antialiasing: true
        }
    }
}
