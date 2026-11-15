import QtQuick
import qs.modules.common

// The huge, faint logo behind the page on the first and the last slide of the
// reference video: the same lettering as the logo, far bigger than the screen,
// drawn as a hollow outline in a shade just off the page colour, and cut off by
// the edges. It is made of plain text, drawn once, and kept as one texture
// (layer) so fading it in and out costs next to nothing.
Item {
    id: root

    property color page: "#090c12"
    property color rim: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.085)
    property color inside: Qt.rgba(Theme.accentMint.r, Theme.accentMint.g, Theme.accentMint.b, 0.025)
    // 0..1 for how much of it shows (the page fades it with the slides).
    property real shown: 1

    // The lettering is sized by the page's width, but never taller than the screen.
    readonly property real fontPx: Math.min(root.width * 0.23, root.height * 0.68)
    readonly property real rimPx: root.fontPx * 0.022
    readonly property var axes: ({})

    opacity: root.shown
    visible: root.shown > 0.001
    clip: true

    Item {
        id: art

        anchors.centerIn: parent
        width: root.width
        height: root.height
        layer.enabled: root.visible
        layer.smooth: true

        component Lines: Item {
            id: lines

            property color ink: "#000"
            property real dx: 0
            property real dy: 0

            Text {
                x: lines.dx
                y: lines.dy
                text: "DECKARDS"
                color: lines.ink
                font.family: Theme.displayFontFamily
                font.pixelSize: root.fontPx
                font.weight: Font.Black
            }

            Text {
                x: lines.dx + root.fontPx * 1.05
                y: lines.dy + root.fontPx * 0.82
                text: "DECK"
                color: lines.ink
                font.family: Theme.displayFontFamily
                font.pixelSize: root.fontPx * 1.12
                font.weight: Font.Black
            }
        }

        Item {
            x: -root.fontPx * 0.08
            y: root.height * 0.5 - root.fontPx * 1.02

            Repeater {
                model: 16

                Lines {
                    required property int index

                    ink: root.rim
                    dx: Math.cos(index * Math.PI / 8) * root.rimPx
                    dy: Math.sin(index * Math.PI / 8) * root.rimPx
                }
            }

            Lines {
                ink: root.inside
            }
        }
    }
}
