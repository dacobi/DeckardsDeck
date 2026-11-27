import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// One big tile of the Settings menu: a wide leaning plate with a coloured
// diamond holding the page's icon, its name large underneath, a line about
// what is on the page, and a big faint number in the corner, like the
// buttons of a rhythm game's main menu. Hovering lights it up with the
// accent wipe; it presses into its shadow like every other key.
//
// Pure UI: SettingsFace places six of them and turns clicked() into
// "open that page". `slot` picks the tile's colour from the five card
// colours; `badge` is a pink dot ("something is waiting", used on About
// when an update exists).
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property int number: 1
    property int slot: 0
    property bool badge: false

    // The plate's size (its shadow is drawn outside it).
    property real tileW: 400
    property real tileH: 277

    signal clicked()

    readonly property bool hovered: area.containsMouse
    readonly property color accent: mt.attributeColors[slot % mt.attributeColors.length]
    readonly property bool edgy: mt.settingsEdgy

    implicitWidth: tileW + 9
    implicitHeight: tileH + 7

    SekaiKey {
        id: key

        capW: root.tileW
        capH: root.tileH
        edgy: root.edgy
        skew: 0.08 * mt.settingsLean
        radius: 40
        lit: root.hovered
        hovered: root.hovered
        pressed: area.pressed
        flatShadow: mt.settingsFlat
        borderBase: 4
        borderLit: 4.5
        ringExtra: 7
        shadowBaseX: 6
        shadowBaseY: 5

        readonly property color ink: root.edgy
            ? (litP > 0.5 ? mt.accentCyan : mt.pInk)
            : Qt.tint(mt.pInk, Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, litP))

        // Cyberdeck left vertical neon accent bar
        Rectangle {
            visible: root.edgy
            x: 8
            y: 18
            width: 4
            height: key.capH - 36
            radius: 1
            color: key.litP > 0.5 ? mt.accentCyan : root.accent
        }

        // the big number
        Text {
            x: key.capW - implicitWidth - (root.edgy ? 32 : 46)
            y: root.edgy ? 22 : 20
            text: root.edgy ? ("0" + root.number) : ("0" + root.number)
            color: root.edgy
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.36)
                : Qt.rgba(key.ink.r, key.ink.g, key.ink.b, 0.14)
            font.family: root.edgy ? mt.monoFontFamily : mt.fontFamily
            font.pixelSize: root.edgy ? 54 : 68
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }

        // the icon badge (angular HUD housing in Cyberpunk mode, rotated diamond in SekaiPop)
        Rectangle {
            x: (root.edgy ? 76 : 88) - width / 2
            y: (root.edgy ? 92 : 100) - height / 2
            width: 66
            height: 66
            radius: root.edgy ? mt.settingsRadiusInner : 18
            rotation: root.edgy ? 0 : 45
            color: root.edgy ? mt.hudSurface : root.accent
            border.width: root.edgy ? 2 : 4
            border.color: root.edgy ? root.accent : (key.litP > 0.5 ? mt.colBorder : mt.pLine)
            antialiasing: true
        }

        MaterialIcon {
            x: (root.edgy ? 76 : 88) - width / 2
            y: (root.edgy ? 92 : 100) - height / 2
            size: 40
            name: root.icon
            weight: mt.settingsIconWeight
            color: root.edgy ? root.accent : mt.colBorder
        }

        Rectangle {
            visible: root.badge
            x: 122
            y: 44
            width: 22
            height: 22
            radius: root.edgy ? mt.settingsRadiusInner : 11
            color: root.edgy ? mt.accentYellow : ScrapbookTheme.accentPink
            border.width: root.edgy ? 2 : 3.5
            border.color: root.edgy ? mt.hudSurface : mt.pLine
            antialiasing: true
        }

        Text {
            x: 42
            y: key.capH - 108
            width: key.capW - 84
            elide: Text.ElideRight
            text: root.edgy ? root.label.toUpperCase() : root.label
            color: key.ink
            font.family: mt.fontFamily
            font.pixelSize: root.edgy ? 34 : 40
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            font.letterSpacing: root.edgy ? 0.8 : 0
            lineHeight: 44
            lineHeightMode: Text.FixedHeight
        }

        Text {
            x: 42
            y: key.capH - 60
            width: key.capW - 84
            elide: Text.ElideRight
            text: root.subtitle
            color: root.edgy
                ? (key.litP > 0.5 ? mt.accentYellow : mt.pInkSub)
                : (key.litP > 0.5 ? Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.78) : mt.pInkSub)
            font.family: root.edgy ? mt.monoFontFamily : mt.fontFamily
            font.pixelSize: root.edgy ? 15 : 19
            font.weight: root.edgy ? Font.Bold : Font.DemiBold
        }

        // Cyberdeck diagonal stripe telemetry bar (when root.edgy is true)
        CyberStripe {
            visible: root.edgy
            x: key.capW - 136
            y: 132
            width: 104
            height: 10
            mode: "stripes"
            fillRatio: key.litP > 0.5 ? 1.0 : 0.72
            color: root.accent
            altColor: mt.accentYellow
            trackColor: Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.28)
            stripeWidth: 5
            gap: 3
        }

        // three stripes between the number and the name, in the next card colours (SekaiPop mode)
        Repeater {
            model: root.edgy ? 0 : 3

            delegate: Slant {
                required property int index

                x: key.capW - 132 + index * 24
                y: 124
                width: 30
                height: 27
                skew: 0.55
                radius: 3
                color: mt.attributeColors[(root.slot + 1 + index) % mt.attributeColors.length]
            }
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.tileW
        height: root.tileH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
