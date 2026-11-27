import QtQuick
import Quickshell
import qs.modules.common
import "../functions/NotifyKinds.js" as NK

// The shell's own notification icon: the badge a screenshot, a recording, a
// timer or an error wears, so it is told apart at a glance from the app and
// browser notifications (which show the app's own icon). It is the Project
// SEKAI card-attribute look: a pastel fill (Cool / Cute / Happy / Mysterious /
// Pure, picked from the glyph by NotifyKinds.js), a white glyph outlined in
// the attribute outline colour, a thick outline and a hard offset shadow, in
// the same #555473 the attribute icons use.
//
//   ShellBadge { size: 56; glyph: "photo_camera" }
//
// `glyph` is the Material Symbols name, the part after "material:" in the
// notification's icon. The shadow is drawn outside the item's box (down-right,
// `size * 0.05`), so leave a little room for it. Nothing here moves or
// repaints on its own: it is a handful of static shapes.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)
    property bool edgy: mt.edgy

    property string glyph: ""
    property real size: 56

    readonly property int kind: NK.index(root.glyph)
    readonly property color fillColor: mt.attributeColors[root.kind]
    readonly property var neonColors: [
        mt.accentCyan,
        mt.accentRed,
        mt.accentYellow,
        mt.accentMint,
        mt.accentGreen
    ]
    readonly property color neonColor: root.neonColors[root.kind % root.neonColors.length]
    // Outline and shadow: the same colour in the shell's attribute icons.
    readonly property color ink: mt.mono ? mt.colBorder : "#555473"
    readonly property real outline: root.edgy ? 1.5 : Math.max(2, root.size * 0.055)
    readonly property real glyphSize: Math.round(root.size * (root.edgy ? 0.56 : 0.6))
    readonly property real boxRadius: root.edgy ? Math.max(2, Math.round(root.size * 0.08)) : root.size * 0.34

    width: root.size
    height: root.size

    // Hard shadow.
    Rectangle {
        x: Math.round(root.size * 0.05)
        y: Math.round(root.size * 0.05)
        width: root.size
        height: root.size
        radius: root.boxRadius
        color: root.edgy ? mt.pLineShadow : root.ink
        antialiasing: true
    }

    // Outline + fill (angular dark HUD module in Cyberpunk mode, pastel attribute badge in SekaiPop).
    Rectangle {
        anchors.fill: parent
        radius: root.boxRadius
        color: root.edgy ? mt.hudSurface : root.fillColor
        border.width: root.outline
        border.color: root.edgy ? root.neonColor : root.ink
        antialiasing: true

        // Subtle inner neon tint in Cyberpunk mode
        Rectangle {
            visible: root.edgy
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(1, root.boxRadius - 1)
            color: Qt.rgba(root.neonColor.r, root.neonColor.g, root.neonColor.b, 0.14)
        }

        // Top-left and bottom-right tactical HUD corner accents
        Rectangle {
            visible: root.edgy
            x: 3
            y: 3
            width: Math.max(6, Math.round(root.size * 0.18))
            height: 2
            color: root.neonColor
        }
        Rectangle {
            visible: root.edgy
            x: 3
            y: 3
            width: 2
            height: Math.max(6, Math.round(root.size * 0.18))
            color: root.neonColor
        }
        Rectangle {
            visible: root.edgy
            x: parent.width - width - 3
            y: parent.height - height - 3
            width: Math.max(6, Math.round(root.size * 0.18))
            height: 2
            color: root.neonColor
        }
    }

    // A soft highlight, top-left, so the badge reads as a raised key (classic mode only).
    Rectangle {
        visible: !root.edgy
        x: root.size * 0.17
        y: root.size * 0.13
        width: root.size * 0.30
        height: root.size * 0.13
        radius: height / 2
        rotation: -24
        color: Qt.rgba(1, 1, 1, 0.5)
        antialiasing: true
    }

    // The glyph's outline: the glyph drawn eight times around a small
    // circle, in the outline colour; the white one goes on top (classic mode only).
    Repeater {
        model: root.edgy ? 0 : 8

        delegate: MaterialIcon {
            required property int index

            readonly property real a: index * Math.PI / 4
            readonly property real r: Math.max(1.4, root.glyphSize * 0.055)

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.cos(a) * r
            anchors.verticalCenterOffset: Math.sin(a) * r
            size: root.glyphSize
            width: root.glyphSize + 12
            height: root.glyphSize + 12
            fill: 1
            weight: 600
            color: root.ink
            name: root.glyph
        }
    }

    // Subtle neon glow behind the glyph in Cyberpunk mode
    MaterialIcon {
        visible: root.edgy
        anchors.centerIn: parent
        size: root.glyphSize + 3
        width: root.glyphSize + 14
        height: root.glyphSize + 14
        fill: mt.iconFill
        weight: 700
        color: Qt.rgba(root.neonColor.r, root.neonColor.g, root.neonColor.b, 0.28)
        name: root.glyph
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: root.glyphSize
        width: root.glyphSize + 12
        height: root.glyphSize + 12
        fill: root.edgy ? mt.iconFill : 1
        weight: 600
        color: root.edgy ? root.neonColor : "#ffffff"
        name: root.glyph
    }
}
