import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// The Settings Panel's tile: what SettingToggle, SettingAction and
// SettingStepper are drawn with. A leaning keycap with a diamond badge for
// the icon, a name and a second line, and the same ways of lighting up and
// being pressed as the Quick Panel's tiles (see SekaiKey). Not something
// a page uses directly.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool lit: false
    // Header-button behaviour: hovering lights it up too.
    property bool hoverLights: false
    // false for a tile that holds its own buttons (the stepper).
    property bool clickable: true
    property real tileWidth: 300
    // Room kept free on the right for something placed inside the tile.
    property real textRightPad: 26

    readonly property real capH: 70
    readonly property bool hovered: area.containsMouse && clickable
    readonly property bool edgy: mt.settingsEdgy

    signal clicked()

    // Observe hover independently of the click area: steppers have their own
    // buttons and disable that area, but their labels still need to be readable.
    HoverHandler {
        id: textHover
    }


    // Anything declared inside the tile goes in its content box (which leans
    // with the plate, like the icon and the writing).
    default property alias extra: key.content

    implicitWidth: tileWidth + 6
    implicitHeight: capH + 4

    // Pulses by itself when `lit` changes without a click on this tile (the
    // setting was changed from the Quick Panel, say).
    property bool keyPulse: false
    property bool suppressPulse: false

    onLitChanged: {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 600
        onTriggered: root.suppressPulse = false
    }

    SekaiKey {
        id: key

        capW: root.tileWidth
        capH: root.capH
        edgy: root.edgy
        skew: 0.2 * mt.settingsLean
        radius: 26
        lit: root.lit || (root.hoverLights && root.hovered)
        hovered: root.hovered
        pressed: (area.pressed && root.clickable) || root.keyPulse
        flatShadow: mt.settingsFlat

        readonly property color ink: root.edgy
            ? (litP > 0.5 ? mt.accentCyan : (root.hovered ? mt.accentMint : mt.pInk))
            : Qt.tint(mt.pInk, Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, litP))
        readonly property real badgeX: root.edgy ? 40 : 48

        // Cyberdeck vertical neon LED status bar (matches QuickToggle.qml)
        Rectangle {
            visible: root.edgy
            x: 6
            y: 12
            width: 3
            height: key.capH - 24
            radius: 1
            color: key.litP > 0.5 ? mt.accentGreen : Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.45)
        }

        // the icon badge (angular HUD square in Cyberpunk mode, rotated diamond in SekaiPop)
        Rectangle {
            x: key.badgeX - width / 2
            y: (key.capH - height) / 2
            width: 33
            height: 33
            radius: root.edgy ? mt.settingsRadiusInner : 9
            rotation: root.edgy ? 0 : 45
            color: root.edgy
                ? mt.hudSurface
                : Qt.tint(mt.pSurfaceDivider, Qt.rgba(1, 1, 1, key.litP))
            border.width: root.edgy ? 1.5 : 3
            border.color: root.edgy
                ? (key.litP > 0.5 ? mt.accentCyan : mt.accentFrame)
                : (key.litP > 0.5 ? mt.colBorder : mt.pLine)
            antialiasing: true
        }

        MaterialIcon {
            visible: root.icon !== ""
            x: key.badgeX - width / 2
            y: (key.capH - height) / 2
            size: 22
            name: root.icon
            fill: mt.iconFill
            color: key.ink
        }

        Column {
            x: key.badgeX + (root.edgy ? 28 : 34)
            width: Math.max(10, key.capW - x - root.textRightPad)
            anchors.verticalCenter: parent.verticalCenter

            SettingsMarquee {
                width: parent.width
                hovered: textHover.hovered
                text: root.edgy ? root.label.toUpperCase() : root.label
                color: key.ink
                font.family: mt.fontFamily
                font.pixelSize: root.edgy ? 16 : 18
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
                lineHeight: 22
            }

            SettingsMarquee {
                width: parent.width
                hovered: textHover.hovered
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.edgy
                    ? (key.litP > 0.5 ? mt.accentYellow : mt.pInkSub)
                    : (key.litP > 0.5 ? Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.78) : mt.pInkSub)
                font.family: root.edgy ? mt.monoFontFamily : mt.fontFamily
                font.pixelSize: root.edgy ? 13 : 15
                font.weight: root.edgy ? Font.Bold : Font.DemiBold
                lineHeight: 20
            }
        }
    }

    MouseArea {
        id: area
        x: 0
        y: 0
        width: root.tileWidth
        height: root.capH
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.suppressPulse = true
        onReleased: suppressGrace.restart()
        onCanceled: suppressGrace.restart()
        onClicked: root.clicked()
    }
}
