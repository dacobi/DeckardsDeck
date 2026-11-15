import QtQuick
import Quickshell
import qs.modules.common

// What the Settings Panel's cards sit on. Not plain white: a pale wash of the
// theme's mint with a halftone fading in from the corners, a few wide
// diagonal bands (cyan, pink, yellow, the same way Project SEKAI's menus
// stripe their backgrounds) and some stars and notes. Everything here is
// decoration; nothing takes the mouse.
//
// `color` is the flat colour of the wash; the page uses it for the soft
// fades at the top and bottom of the scrolling area.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property color base: mt.pSurface
    readonly property bool deep: mt.dark && !mt.classic
    readonly property color color: mt.edgy && root.deep
        ? Qt.tint(Qt.color("#07080e"), Qt.rgba(mt.hudTint.r, mt.hudTint.g, mt.hudTint.b, 0.55))
        : Qt.tint(base, Qt.rgba(mt.accentMint.r, mt.accentMint.g, mt.accentMint.b, deep ? 0.12 : 0.17))

    function mix(c, a) {
        const q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    Rectangle {
        anchors.fill: parent
        color: root.color
    }

    // diagonal bands (classic mode)
    Slant {
        visible: !mt.edgy
        x: -150
        y: -30
        width: 560
        height: 820
        skew: 0.34
        color: root.mix(mt.accentCyan, root.deep ? 0.12 : 0.16)
    }

    Slant {
        visible: !mt.edgy
        x: 190
        y: -30
        width: 420
        height: 820
        skew: 0.34
        color: root.mix(ScrapbookTheme.accentPink, root.deep ? 0.10 : 0.16)
    }

    Slant {
        visible: !mt.edgy
        x: 330
        y: -30
        width: 340
        height: 820
        skew: 0.34
        color: root.mix(mt.attributeColors[2], root.deep ? 0.08 : 0.22)
    }

    // halftones (classic mode)
    DotField {
        visible: !mt.edgy
        x: root.width - width
        y: 0
        width: 640
        height: 260
        corner: "tr"
        spacing: 20
        maxRadius: 4.2
        dotColor: root.mix(mt.colBorder, root.deep ? 0.22 : 0.10)
    }

    DotField {
        visible: !mt.edgy
        x: 0
        y: root.height - height
        width: 420
        height: 300
        corner: "bl"
        spacing: 20
        maxRadius: 4.2
        dotColor: root.mix(mt.colBorder, root.deep ? 0.22 : 0.10)
    }

    // Cyberpunk 2077 / Anna Kuzminska HUD Backdrop (when mt.edgy is true)
    Item {
        anchors.fill: parent
        visible: mt.edgy

        CyberStripe {
            anchors.fill: parent
            anchors.margins: 12
            mode: "grid"
            gridStep: 36
            crossSize: 3
            color: root.mix(mt.accentCyan, root.deep ? 0.09 : 0.12)
        }

        // Top-left Acid Yellow HUD hero callout strip + Arasaka Red hairline trace
        Rectangle {
            x: 0
            y: 0
            width: Math.min(240, parent.width * 0.42)
            height: 4
            color: mt.accentYellow
        }

        Rectangle {
            x: 0
            y: 6
            width: parent.width
            height: 1
            color: root.mix(mt.accentFrame, 0.42)
        }

        // Diagonal //////// telemetry hazard strip in top-right
        CyberStripe {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            width: 120
            height: 7
            mode: "stripes"
            barWidth: 5
            gap: 4
            progress: 0.65
            color: root.mix(mt.accentCyan, 0.65)
            altColor: mt.accentYellow
            trackColor: root.mix(mt.accentFrame, 0.28)
        }

        // Bottom-left >>>> chevrons + BIO MONITOR serial code
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 10

            CyberStripe {
                width: 48
                height: 10
                anchors.verticalCenter: parent.verticalCenter
                mode: "chevrons"
                barWidth: 4
                gap: 4
                color: root.mix(mt.accentFrame, 0.72)
                altColor: mt.accentYellow
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BIO MONITOR // 382 248 40270274 -- NC-77"
                font.family: "JetBrains Mono"
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.4
                color: root.mix(mt.accentAmber, 0.68)
            }
        }
    }

    // cyberdeck HUD telemetry glyphs
    MaterialIcon {
        x: 112
        y: 664
        size: 42
        name: "radar"
        fill: 0
        rotation: 0
        color: root.mix(mt.attributeColors[2], 0.65)
    }

    MaterialIcon {
        x: 238
        y: 690
        size: 30
        name: "my_location"
        fill: 0
        rotation: 0
        color: root.mix(ScrapbookTheme.accentPink, 0.65)
    }

    MaterialIcon {
        x: 62
        y: 586
        size: 26
        name: "memory"
        fill: 0
        rotation: 0
        color: root.mix(mt.accentCyan, 0.70)
    }
}
