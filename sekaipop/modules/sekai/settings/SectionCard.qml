import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// A white panel with the Quick Panel's outline and hard shadow, wearing a
// leaning name plate on its top edge (a Project SEKAI header), a few
// slanted stripes on the other end and a halftone in its corner. Each card
// in a page takes the next of the five card-attribute colours for its plate
// (cool, cute, happy, mysterious, pure), so a page reads as a row of
// different things instead of the same box repeated.
//
// Put controls inside; they wrap into rows (a Flow), so give each one the
// width it wants and a full-width one (`width: card.innerWidth`) for a row
// of its own.
//
//   SectionCard {
//       title: "Modules"
//       icon: "extension"           // optional; most titles already have one
//       SettingToggle { ... }
//   }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string title: ""
    property string icon: ""
    property real inset: 26
    width: parent ? parent.width : 600
    property real gap: 16
    default property alias content: flow.data

    // The width a full-width control inside the card may take.
    readonly property real innerWidth: card.width - inset * 2

    readonly property bool isSectionCard: true
    // Which card of its page this is (counted among its siblings), so the
    // plates take the attribute colours in turn.
    property int slot: 0

    Component.onCompleted: {
        if (!parent)
            return
        let n = 0
        for (let i = 0; i < parent.children.length; i++) {
            const c = parent.children[i]
            if (c === root)
                break
            if (c.isSectionCard === true)
                n++
        }
        slot = n
    }

    readonly property color accent: mt.attributeColors[slot % mt.attributeColors.length]
    readonly property bool edgy: mt.settingsEdgy

    readonly property var iconFor: ({
        "look": "palette", "shell": "widgets", "bar": "toast", "desktop widgets": "dashboard",
        "cyberdeck": "smartphone", "settings panel": "tune", "quick panel style": "smartphone",
        "time & alerts": "schedule", "quick panel": "instant_mix", "launcher & lock": "lock",
        "modules": "extension", "utility keys": "keyboard", "size": "aspect_ratio",
        "wallpaper": "wallpaper", "widgets": "dashboard", "dock": "dock_to_bottom", "effects": "auto_awesome",
        "one-time setup": "rocket_launch", "gaps & borders": "border_style", "windows": "select_window",
        "animations": "animation", "workspaces & layout": "grid_view", "input & display": "mouse",
        "hyprland": "grid_view", "this shell": "info", "update": "system_update_alt",
        "what's new": "campaign", "credits": "favorite"
    })
    readonly property string shownIcon: icon !== "" ? icon : (iconFor[title.toLowerCase()] || "star")

    implicitHeight: 30 + flow.implicitHeight + 30 + 4

    // hard shadow
    Rectangle {
        x: mt.settingsFlat ? 0 : 5
        y: 4
        width: card.width
        height: card.height
        radius: root.edgy ? mt.settingsRadiusOuter : 30
        color: mt.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        width: root.width - 5
        height: root.height - 4
        radius: root.edgy ? mt.settingsRadiusOuter : 30
        color: root.edgy ? mt.hudSurface : mt.pSurface
        border.width: root.edgy ? 2 : 3
        border.color: root.edgy ? mt.accentFrame : mt.pLine
        antialiasing: true
        clip: root.edgy

        CyberStripe {
            visible: root.edgy
            anchors.fill: parent
            anchors.margins: 8
            mode: "grid"
            color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.09)
            gap: 18
        }

        // Cyberdeck corner accent bars on SectionCard
        Rectangle {
            visible: root.edgy
            x: 0; y: 0; width: 22; height: 4
            color: root.accent
        }
        Rectangle {
            visible: root.edgy
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 28; height: 4
            color: mt.accentYellow
        }

        DotField {
            visible: !root.edgy
            x: card.width - width - 16
            y: card.height - height - 16
            width: 300
            height: 110
            corner: "br"
            spacing: 16
            maxRadius: 3
            dotColor: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.07)
        }

        Flow {
            id: flow
            x: root.inset
            y: 30
            width: card.width - root.inset * 2
            spacing: root.gap
        }
    }

    // The name plate, leaning, lying across the card's top edge.
    SekaiKey {
        id: plate

        x: 34
        y: -22
        capW: 18 + 36 + 10 + tagText.implicitWidth + 38
        capH: 44
        edgy: root.edgy
        skew: 0.3 * mt.settingsLean
        radius: 15
        shadowBaseX: 3
        shadowBaseY: 3
        flatShadow: mt.settingsFlat
        idleColor: root.edgy ? mt.hudSurface : root.accent

        Rectangle {
            x: root.edgy ? 16 : 40
            y: (plate.capH - height) / 2
            width: 28
            height: 28
            radius: root.edgy ? mt.settingsRadiusInner : 8
            rotation: root.edgy ? 0 : 45
            color: root.edgy ? mt.hudSurface : mt.colBg
            border.width: root.edgy ? 1.5 : 2.5
            border.color: root.edgy ? root.accent : mt.pLine
            antialiasing: true
        }

        MaterialIcon {
            x: (root.edgy ? 16 : 40) + 14 - 11
            y: (plate.capH - height) / 2
            size: 22
            name: root.shownIcon
            weight: mt.settingsIconWeight
            color: root.edgy ? root.accent : mt.colBorder
        }

        Text {
            id: tagText
            x: (root.edgy ? 16 : 40) + 28 + 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.edgy ? root.title.toUpperCase() : root.title
            color: root.edgy ? root.accent : mt.colBorder
            font.family: mt.fontFamily
            font.pixelSize: root.edgy ? 19 : 21
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            font.letterSpacing: root.edgy ? 0.8 : 0
        }
    }

    // Cyberdeck diagonal stripe telemetry bar at top-right of SectionCard
    CyberStripe {
        visible: root.edgy
        x: card.width - 134
        y: -7
        width: 108
        height: 10
        mode: "stripes"
        fillRatio: 0.78
        color: root.accent
        altColor: mt.accentYellow
        trackColor: Qt.rgba(mt.accentFrame.r, mt.accentFrame.g, mt.accentFrame.b, 0.32)
        stripeWidth: 5
        gap: 3
    }

    // Three stripes at the other end of the edge (SekaiPop mode).
    Repeater {
        model: root.edgy ? 0 : 3

        delegate: Slant {
            required property int index

            x: card.width - 108 + index * 22
            y: -13
            width: 30
            height: 27
            skew: 0.55
            radius: 3
            color: mt.attributeColors[(root.slot + 1 + index) % mt.attributeColors.length]
        }
    }
}
