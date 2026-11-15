import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common

// The header plate every bar popup (Weather, Calendar, Battery, Discord) opens
// with: a gradient slab on the shell's Pill (outline, ring, hard shadow) with
// a printed halftone in one corner and two slanted bands of stage light, the
// look the Discord panel's blurple plate already had, made reusable so the four
// cards read as one family. Things declared inside land on top of the plate
// and are NOT clipped, so a sticker numeral or a tilted stamp can break out
// over the plate's edge. Their coordinates are the plate's own: (0, 0) is its
// top-left corner and the face is `height - Theme.shadowOffset` tall.
//
//   SekaiPlate {
//       width: 304; height: 104
//       colorTop: Theme.accentMint; colorBottom: Theme.accentCyan
//       StickerText { x: 12; y: 0; text: "24"; pixelSize: 60 }
//   }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property color colorTop: mt.accentMint
    property color colorBottom: mt.accentCyan
    property real cornerRadius: mt.edgy ? mt.radiusInner : 12
    // Outline + the white line (Theme.whiteLine): the same as every block's.
    property real ringWidth: mt.borderWidth + mt.whiteLine
    // The halftone and the light bands. Dark dots / white bands suit a light
    // plate; a dark plate wants the other way round (set dotColor).
    property color dotColor: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.16)
    property color bandColor: Qt.rgba(1, 1, 1, 0.14)
    property string dotCorner: "tr"
    property real dotSpacing: 14
    property bool pressed: false

    // Big sticker numerals on the plate: a DARK fill inside the white ring in classic mode,
    // or glowing Electric Cyan inside a dark void ring on the Cyberpunk HUD header module.
    readonly property color numberFill: mt.edgy ? mt.accentCyan : Qt.darker(mt.colBorder, 1.8)
    readonly property color numberRing: mt.edgy ? Qt.color("#06070c") : "#ffffff"

    // The part of the plate above its hard shadow.
    readonly property real faceHeight: root.height - mt.shadowOffset

    default property alias content: layer.data

    implicitHeight: 100 + mt.shadowOffset

    Gradient {
        id: plateGradient
        GradientStop {
            position: 0.0
            color: mt.edgy
                ? Qt.tint(mt.hudTint, Qt.rgba(root.colorTop.r, root.colorTop.g, root.colorTop.b, 0.22))
                : root.colorTop
        }
        GradientStop {
            position: 1.0
            color: mt.edgy
                ? Qt.tint(Qt.color("#07080e"), Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.14))
                : root.colorBottom
        }
    }

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        ringWidth: root.ringWidth
        fillGradient: plateGradient
        pressed: root.pressed

        ClippingRectangle {
            anchors.fill: parent
            radius: Math.max(0, root.cornerRadius - root.ringWidth)
            color: "transparent"

            DotField {
                visible: !mt.edgy
                anchors.fill: parent
                corner: root.dotCorner
                spacing: root.dotSpacing
                maxRadius: 3.4
                reach: 0.95
                dotColor: root.dotColor
            }
            Slant {
                visible: !mt.edgy
                x: parent.width * 0.56
                y: -8
                width: 46
                height: parent.height + 16
                skew: 0.22
                radius: 0
                color: root.bandColor
            }
            Slant {
                visible: !mt.edgy
                x: parent.width * 0.56 + 56
                y: -8
                width: 20
                height: parent.height + 16
                skew: 0.22
                radius: 0
                color: root.bandColor
            }

            // Cyberpunk 2077 / Anna Kuzminska HUD header telemetry overlay
            Item {
                anchors.fill: parent
                visible: mt.edgy

                CyberStripe {
                    anchors.fill: parent
                    anchors.margins: 4
                    mode: "grid"
                    gridStep: 24
                    crossSize: 2.5
                    color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.14)
                }

                // Top-left high-voltage Acid Yellow telemetry header strip
                Rectangle {
                    x: 0
                    y: 0
                    width: Math.min(88, parent.width * 0.34)
                    height: 3
                    color: mt.accentYellow
                }

                // Top-right >>>> chevron cluster in Arasaka Red + Acid Yellow
                CyberStripe {
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    width: 42
                    height: 9
                    mode: "chevrons"
                    barWidth: 4
                    gap: 4
                    color: Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.72)
                    altColor: mt.accentYellow
                }

                // Bottom-edge diagonal //////// HUD hazard/telemetry stripe bar
                CyberStripe {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    height: 5
                    mode: "stripes"
                    barWidth: 4
                    gap: 3
                    progress: 0.72
                    color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.55)
                    altColor: mt.accentYellow
                    trackColor: Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.28)
                }

                // Right-edge Bio-Green status marker
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2.5
                    height: Math.max(12, parent.height * 0.36)
                    color: mt.accentGreen
                    opacity: 0.85
                }
            }
        }
    }

    Item {
        id: layer
        width: root.width
        height: root.faceHeight
    }
}
