import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A pill button for the Palette tool, in the bar's pill language: outline, flat
// fill, a hard shadow straight down that the face sinks into when pressed.
//
//   PaletteButton { icon: "casino"; label: "Shuffle"; onClicked: ... }
//   PaletteButton { primary: true; label: "Apply to theme" }   // accent fill
//   PaletteButton { lit: true }                                // switched on (Save, once saved)
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: ""
    property string label: ""
    property bool primary: false
    property bool lit: false

    signal clicked()

    readonly property real lift: 3
    readonly property bool hovered: mouse.containsMouse && root.enabled

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34 + root.lift
    opacity: root.enabled ? 1 : 0.45

    readonly property color inkColor: mt.edgy
        ? (root.primary ? mt.accentCyan : (root.lit ? mt.accentYellow : (root.hovered ? mt.accentMint : mt.ink)))
        : ((root.primary || root.lit) ? mt.colBorder : mt.ink)

    Pill {
        id: face
        width: root.width + shadowDx
        height: 34 + shadowDy
        edgy: mt.edgy
        cornerRadius: mt.edgy ? mt.radiusInner : 12
        borderWidth: 2
        ringWidth: 2
        shadowDx: mt.edgy ? 2 : 0
        shadowDy: root.lift
        pressed: mouse.pressed && root.enabled
        borderColor: mt.edgy
            ? (root.primary || root.lit ? mt.accentCyan : (root.hovered ? mt.accentMint : mt.accentFrame))
            : mt.line
        fillColor: mt.edgy
            ? (root.primary
                ? Qt.tint(mt.hudSurface, Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.22))
                : (root.lit
                    ? Qt.tint(mt.hudSurface, Qt.rgba(mt.accentYellow.r, mt.accentYellow.g, mt.accentYellow.b, 0.18))
                    : (root.hovered ? Qt.lighter(mt.hudSurface, 1.25) : mt.hudSurface)))
            : (root.primary ? mt.accentCyan : (root.lit ? mt.accentMint : (root.hovered ? mt.surfaceTint : mt.surface)))

        Item {
            x: -face.ringWidth
            y: -face.ringWidth
            width: face.capWidth
            height: face.capHeight

            // Cyberdeck vertical LED status marker
            Rectangle {
                visible: mt.edgy && (root.primary || root.lit)
                x: 4
                y: 8
                width: 2
                height: parent.height - 16
                color: root.primary ? mt.accentCyan : mt.accentYellow
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    visible: root.icon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.icon
                    size: 18
                    color: root.inkColor
                }

                Text {
                    visible: root.label !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: mt.edgy ? root.label.toUpperCase() : root.label
                    color: root.inkColor
                    font.family: mt.edgy ? mt.monoFontFamily : mt.fontFamily
                    font.pixelSize: mt.edgy ? 11 : 13
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                    font.letterSpacing: mt.edgy ? 0.5 : 0
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
