import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/MatugenMath.js" as MG
import "../../common/functions/PaletteMath.js" as PM

// The Custom palette's interactive role & colour picker, shown in Edit Desktop > THEME
// next to the theme tiles when "Custom palette" is tuned (EditThemeBoard.qml).
// Each role sets `custom.pin*` in SettingsService so the whole shell updates live.
Item {
    id: root

    signal back()
    signal finished()

    readonly property color navy: Theme.pLine
    readonly property color inkSub: Theme.pInkSub
    readonly property color cardBg: Theme.pSurface
    readonly property color wellBg: Theme.pSurfaceHover
    readonly property color hiFill: Theme.accentMint

    readonly property var roles: [
        { id: "A",       label: "Primary",   key: "custom.pinA",       prop: "A",       def: "#00f0ff" },
        { id: "B",       label: "Secondary", key: "custom.pinB",       prop: "B",       def: "#38bdf8" },
        { id: "C",       label: "Frame",     key: "custom.pinC",       prop: "C",       def: "#ff2a55" },
        { id: "D",       label: "Highlight", key: "custom.pinD",       prop: "D",       def: "#7dd3fc" },
        { id: "E",       label: "Status",    key: "custom.pinE",       prop: "E",       def: "#00ff7f" },
        { id: "border",  label: "Outline",   key: "custom.pinBorder",  prop: "border",  def: "#1e3448" },
        { id: "deep",    label: "Surface",   key: "custom.pinDeep",    prop: "deep",    def: "#070b12" },
        { id: "hudTint", label: "HUD Tint",  key: "custom.pinHudTint", prop: "hudTint", def: "#0b1622" }
    ]

    property int activeRoleIndex: 0
    readonly property var activeRole: root.roles[root.activeRoleIndex] || root.roles[0]

    function roleColor(r) {
        const pin = MG.cleanHex(SettingsService.get(r.key))
        if (pin !== "")
            return pin
        const pal = ThemeService.customPalette || ThemeService.customBasePalette
        if (pal && pal[r.prop])
            return String(pal[r.prop])
        return r.def
    }

    function rolePinned(r) {
        return MG.cleanHex(SettingsService.get(r.key)) !== ""
    }

    readonly property bool anyPinned: root.roles.some(r => root.rolePinned(r))
    readonly property string activeHex: root.roleColor(root.activeRole)

    // Interactive HSV state for the 2D SV picker + Hue bar
    property real pickH: 185
    property real pickS: 1.0
    property real pickV: 1.0
    property bool syncingFromRole: false

    function rgbToHsv(hex) {
        const rgb = PM.toRgb(hex)
        const r = rgb.r / 255, g = rgb.g / 255, b = rgb.b / 255
        const max = Math.max(r, g, b), min = Math.min(r, g, b)
        const d = max - min
        let h = 0
        if (d > 0) {
            if (max === r) h = 60 * (((g - b) / d) % 6)
            else if (max === g) h = 60 * ((b - r) / d + 2)
            else h = 60 * ((r - g) / d + 4)
        }
        if (h < 0) h += 360
        const s = max === 0 ? 0 : d / max
        const v = max
        return { h: h, s: s, v: v }
    }

    function hsvToHex(h, s, v) {
        const hh = ((h % 360) + 360) % 360
        const c = v * s
        const x = c * (1 - Math.abs(((hh / 60) % 2) - 1))
        const m = v - c
        let r = 0, g = 0, b = 0
        if (hh < 60)       { r = c; g = x; b = 0 }
        else if (hh < 120) { r = x; g = c; b = 0 }
        else if (hh < 180) { r = 0; g = c; b = x }
        else if (hh < 240) { r = 0; g = x; b = c }
        else if (hh < 300) { r = x; g = 0; b = c }
        else               { r = c; g = 0; b = x }
        return PM.fromRgb((r + m) * 255, (g + m) * 255, (b + m) * 255)
    }

    function syncPickerFromActive() {
        root.syncingFromRole = true
        const hsv = root.rgbToHsv(root.activeHex)
        if (hsv.s > 0.01)
            root.pickH = hsv.h
        root.pickS = hsv.s
        root.pickV = hsv.v
        if (!hexInput.activeFocus)
            hexInput.text = root.activeHex.slice(1).toUpperCase()
        root.syncingFromRole = false
    }

    onActiveRoleIndexChanged: root.syncPickerFromActive()
    onActiveHexChanged: {
        if (!svMouse.pressed && !hueMouse.pressed)
            root.syncPickerFromActive()
    }
    Component.onCompleted: root.syncPickerFromActive()

    function applyPickedHsv() {
        if (root.syncingFromRole)
            return
        const hex = root.hsvToHex(root.pickH, root.pickS, root.pickV)
        SettingsService.set(root.activeRole.key, hex)
        if (!hexInput.activeFocus)
            hexInput.text = hex.slice(1).toUpperCase()
        if (ThemeService.current !== "custom")
            ThemeService.setTheme("custom")
    }

    function setRoleHex(hex) {
        const clean = MG.cleanHex(hex)
        if (clean === "")
            return
        SettingsService.set(root.activeRole.key, clean)
        if (ThemeService.current !== "custom")
            ThemeService.setTheme("custom")
        root.syncPickerFromActive()
    }

    function resetAllPins() {
        for (let i = 0; i < root.roles.length; i++)
            SettingsService.set(root.roles[i].key, "")
        root.syncPickerFromActive()
    }

    // Screen eyedropper via hyprpicker (when installed)
    property bool hasHyprpicker: false
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprpicker >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.hasHyprpicker = exitCode === 0
        }
    }

    Process {
        id: eyedropProc
        stdout: StdioCollector {
            onStreamFinished: {
                const c = MG.cleanHex(text)
                if (c !== "")
                    root.setRoleHex(c)
            }
        }
    }

    readonly property var presetSwatches: [
        "#00f0ff", "#ff2a55", "#fcee0a", "#00ff7f",
        "#38bdf8", "#a855f7", "#ff9e2c", "#ff2a85",
        "#1e3448", "#0b1622", "#070b12", "#e6e6e6"
    ]

    // Hard shadow
    Rectangle {
        x: card.x + 3
        y: card.y + 4
        width: card.width
        height: card.height
        radius: Theme.edgy ? Theme.radiusInner : 16
        color: Theme.pLineShadow
    }

    // Card body
    Rectangle {
        id: card
        width: Math.min(540, parent.width - 16)
        height: 154
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2) - 2
        radius: Theme.edgy ? Theme.radiusInner : 16
        color: root.cardBg
        border.width: Theme.borderWidth
        border.color: root.navy

        // ===== Header row =====
        Item {
            id: head
            x: 12
            y: 8
            width: card.width - 24
            height: 22

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "palette"
                    size: 15
                    color: root.navy
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CUSTOM SCHEME"
                    color: root.navy
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                    font.letterSpacing: 1.2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// " + root.activeRole.label.toUpperCase()
                    color: root.inkSub
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Open the 5-swatch Palette Tool popup
                Rectangle {
                    width: palToolRow.width + 12
                    height: 20
                    radius: Theme.edgy ? 2 : 7
                    color: palToolMouse.containsMouse ? root.hiFill : root.wellBg
                    border.width: 1.5
                    border.color: root.navy

                    Row {
                        id: palToolRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "auto_fix_high"
                            size: 12
                            color: palToolMouse.containsMouse ? Theme.colBorder : root.navy
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "5-Swatch Tool"
                            color: palToolMouse.containsMouse ? Theme.colBorder : root.navy
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }

                    MouseArea {
                        id: palToolMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            EditMode.close()
                            PaletteService.requestOpen()
                        }
                    }
                }

                // Reset all pinned roles
                Rectangle {
                    visible: root.anyPinned
                    width: resetTxt.implicitWidth + 12
                    height: 20
                    radius: Theme.edgy ? 2 : 7
                    color: resetMouse.containsMouse ? root.hiFill : root.wellBg
                    border.width: 1.5
                    border.color: root.navy

                    Text {
                        id: resetTxt
                        anchors.centerIn: parent
                        text: "Reset"
                        color: resetMouse.containsMouse ? Theme.colBorder : root.navy
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetAllPins()
                    }
                }

                // Close button
                Rectangle {
                    width: 20
                    height: 20
                    radius: Theme.edgy ? 2 : 7
                    color: closeMouse.containsMouse ? root.hiFill : root.wellBg
                    border.width: 1.5
                    border.color: root.navy

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 13
                        color: closeMouse.containsMouse ? Theme.colBorder : root.navy
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.back()
                    }
                }
            }
        }

        // ===== Body: Left (Role Grid + Swatch Seeds) | Right (Interactive 2D Color Picker) =====
        Row {
            x: 12
            y: 34
            spacing: 12

            // Left column: 8 role chips (2 rows x 4 cols) + quick preset swatches
            Column {
                width: 284
                spacing: 7

                Grid {
                    columns: 4
                    columnSpacing: 5
                    rowSpacing: 5

                    Repeater {
                        model: root.roles

                        Rectangle {
                            id: rChip
                            required property var modelData
                            required property int index

                            readonly property bool active: root.activeRoleIndex === index
                            readonly property string col: root.roleColor(modelData)
                            readonly property bool pinned: root.rolePinned(modelData)

                            width: 67
                            height: 36
                            radius: Theme.edgy ? 2 : 8
                            color: rChip.active ? root.hiFill : (rChipMouse.containsMouse ? root.wellBg : root.cardBg)
                            border.width: rChip.active ? 2 : 1.5
                            border.color: root.navy

                            Row {
                                x: 5
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Rectangle {
                                    width: 14
                                    height: 22
                                    radius: Theme.edgy ? 1 : 4
                                    color: rChip.col
                                    border.width: 1.5
                                    border.color: rChip.active ? Theme.colBorder : root.navy
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        width: 40
                                        elide: Text.ElideRight
                                        text: rChip.modelData.label
                                        color: rChip.active ? Theme.colBorder : root.navy
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.ExtraBold
                                        font.styleName: Theme.fontStyleBold
                                    }

                                    Text {
                                        text: rChip.col.toUpperCase()
                                        color: rChip.active ? Theme.colBorder : root.inkSub
                                        opacity: 0.85
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: rChipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeRoleIndex = rChip.index
                                    if (ThemeService.current !== "custom")
                                        ThemeService.setTheme("custom")
                                }
                            }

                            // Tiny reset dot on pinned roles
                            Rectangle {
                                visible: rChip.pinned
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 2
                                width: 10
                                height: 10
                                radius: 5
                                color: root.navy

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 7
                                    color: root.cardBg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.set(rChip.modelData.key, "")
                                        root.syncPickerFromActive()
                                    }
                                }
                            }
                        }
                    }
                }

                // Quick Preset Swatches row
                Row {
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SWATCHES"
                        color: root.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 0.8
                    }

                    Repeater {
                        model: root.presetSwatches

                        Rectangle {
                            required property string modelData
                            width: 16
                            height: 16
                            radius: Theme.edgy ? 2 : 5
                            color: modelData
                            border.width: root.activeHex.toLowerCase() === modelData.toLowerCase() ? 2 : 1
                            border.color: root.navy
                            scale: swMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            MouseArea {
                                id: swMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setRoleHex(modelData)
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: 1
                height: 112
                color: root.navy
                opacity: 0.25
            }

            // Right column: Interactive 2D SV Canvas + Hue Slider + Hex Input + Eyedropper
            Column {
                width: 204
                spacing: 6

                Row {
                    spacing: 8

                    // 2D Saturation / Value Picker Box
                    Item {
                        id: svBox
                        width: 124
                        height: 82

                        // Base Hue fill
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.edgy ? 2 : 6
                            color: root.hsvToHex(root.pickH, 1, 1)
                        }

                        // Horizontal White -> Transparent gradient (Saturation)
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.edgy ? 2 : 6
                            rotation: -90
                            width: parent.height
                            height: parent.width
                            anchors.centerIn: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ffffffff" }
                                GradientStop { position: 1.0; color: "#00ffffff" }
                            }
                        }

                        // Vertical Transparent -> Black gradient (Value)
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.edgy ? 2 : 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#00000000" }
                                GradientStop { position: 1.0; color: "#ff000000" }
                            }
                            border.width: 1.5
                            border.color: root.navy
                        }

                        // Crosshair thumb
                        Rectangle {
                            x: Math.round(root.pickS * (svBox.width - 4)) - 3
                            y: Math.round((1 - root.pickV) * (svBox.height - 4)) - 3
                            width: 10
                            height: 10
                            radius: 5
                            color: root.activeHex
                            border.width: 2
                            border.color: root.pickV > 0.55 ? "#000000" : "#ffffff"
                        }

                        MouseArea {
                            id: svMouse
                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor

                            function updateSv(mx, my) {
                                root.pickS = Math.max(0, Math.min(1, mx / svBox.width))
                                root.pickV = Math.max(0, Math.min(1, 1 - (my / svBox.height)))
                                root.applyPickedHsv()
                            }

                            onPressed: mouse => updateSv(mouse.x, mouse.y)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    updateSv(mouse.x, mouse.y)
                            }
                        }
                    }

                    // Vertical Hue Bar
                    Item {
                        id: hueBox
                        width: 16
                        height: 82

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.edgy ? 2 : 6
                            border.width: 1.5
                            border.color: root.navy
                            gradient: Gradient {
                                GradientStop { position: 0.00; color: "#ff0000" }
                                GradientStop { position: 0.17; color: "#ffff00" }
                                GradientStop { position: 0.33; color: "#00ff00" }
                                GradientStop { position: 0.50; color: "#00ffff" }
                                GradientStop { position: 0.67; color: "#0000ff" }
                                GradientStop { position: 0.83; color: "#ff00ff" }
                                GradientStop { position: 1.00; color: "#ff0000" }
                            }
                        }

                        // Hue thumb
                        Rectangle {
                            x: -1
                            y: Math.round((root.pickH / 360) * (hueBox.height - 6))
                            width: hueBox.width + 2
                            height: 6
                            radius: 2
                            color: "#ffffff"
                            border.width: 1.5
                            border.color: "#000000"
                        }

                        MouseArea {
                            id: hueMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            function updateHue(my) {
                                root.pickH = Math.max(0, Math.min(359.9, (my / hueBox.height) * 360))
                                root.applyPickedHsv()
                            }

                            onPressed: mouse => updateHue(mouse.y)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    updateHue(mouse.y)
                            }
                        }
                    }

                    // Live swatch + Eyedropper column
                    Column {
                        spacing: 6

                        Rectangle {
                            width: 46
                            height: 50
                            radius: Theme.edgy ? 2 : 8
                            color: root.activeHex
                            border.width: 2
                            border.color: root.navy
                        }

                        Rectangle {
                            visible: root.hasHyprpicker
                            width: 46
                            height: 26
                            radius: Theme.edgy ? 2 : 7
                            color: dropMouse.containsMouse ? root.hiFill : root.wellBg
                            border.width: 1.5
                            border.color: root.navy

                            MaterialIcon {
                                anchors.centerIn: parent
                                name: "colorize"
                                size: 15
                                color: dropMouse.containsMouse ? Theme.colBorder : root.navy
                            }

                            MouseArea {
                                id: dropMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!eyedropProc.running)
                                        eyedropProc.exec(["hyprpicker", "-a", "-n"])
                                }
                            }
                        }
                    }
                }

                // Hex input row
                Rectangle {
                    width: 194
                    height: 24
                    radius: Theme.edgy ? 2 : 7
                    color: root.wellBg
                    border.width: hexInput.activeFocus ? 2 : 1.5
                    border.color: root.navy

                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "#"
                            color: root.inkSub
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        TextInput {
                            id: hexInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: 66
                            color: root.navy
                            selectionColor: root.hiFill
                            selectedTextColor: Theme.colBorder
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            maximumLength: 6
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhPreferLatin
                            validator: RegularExpressionValidator {
                                regularExpression: /[0-9a-fA-F]{0,6}/
                            }
                            onTextEdited: {
                                const c = MG.cleanHex(text)
                                if (c.length === 7)
                                    root.setRoleHex(c)
                            }
                            onAccepted: {
                                const c = MG.cleanHex(text)
                                if (c !== "")
                                    root.setRoleHex(c)
                                focus = false
                                root.finished()
                            }
                        }
                    }
                }
            }
        }
    }
}
