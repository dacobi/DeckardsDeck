import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/PaletteMath.js" as PM

// The Palette tool: look at colours, keep the ones you like, and put them on the shell
// only when you say so.
//
//   - Wallpaper / Music: five colours read from the wallpaper on screen, or from the
//     cover of the playing track (PaletteExtractor.qml)
//   - Random: five colours from a colour-wheel harmony (analogous, complementary,
//     split, triadic, tetradic, mono); Space or Shuffle makes a new set, and a locked
//     swatch (padlock, or right-click) keeps its colour through every shuffle
//   - click a swatch to copy its HEX (wl-copy)
//   - the heart saves the palette to the favourites; click a saved one to bring it back
//   - the live preview shows the palette on a mock-up of the shell, in the current
//     light / dark / darker mode
//
// LOOKING NEVER CHANGES THE THEME. The strip, the preview, the shuffle, the favourites
// and the copy buttons only touch PaletteService's own state. The shell changes colour
// only when you press "Apply to theme" (PaletteService.apply(): the palette becomes the
// "Custom palette" theme, in Settings -> Quick -> Colours and the Edit Desktop theme
// row). "Undo" puts the previous theme back.
//
// Ways to open it:
//   qs -c sekaipop ipc call palette toggle       (also show / hide)
//   qs -c sekaipop ipc call palette shuffle      (a new random strip; the theme is untouched)
//   Settings -> Quick -> Colours -> "Palette tool"
//   e.g. in hyprland.lua:  bind = SUPER, P, exec, qs -c sekaipop ipc call palette toggle
// Ways to close it: Escape, the cross, click outside the card, or the keybind again.
//
// Like the cheatsheet, it opens on the focused monitor, drawn inside a ScaleHost so it
// follows the per-monitor UI scale.
Scope {
    id: root

    property bool open: false
    property bool closing: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // the palette as the shell would wear it (for the "how it maps" list)
    readonly property var shell: PM.toShell(PaletteService.colors)

    // the little "copied" tick lives on the swatch; this counts copies for nothing but
    // to let "Copy all" say it did something
    property bool copiedAll: false

    // Which of the 5 swatches is currently open in the inline colour picker (-1 = none).
    property int editingIndex: -1
    readonly property string editingHex: (root.editingIndex >= 0 && root.editingIndex < 5)
        ? (PaletteService.colors[root.editingIndex] ?? "#000000") : "#000000"
    property real pickH: 185
    property real pickS: 1.0
    property real pickV: 1.0
    property bool syncingPicker: false

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
        return { h: h, s: max === 0 ? 0 : d / max, v: max }
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

    function syncPickerFromEditing() {
        if (root.editingIndex < 0)
            return
        root.syncingPicker = true
        const hsv = root.rgbToHsv(root.editingHex)
        if (hsv.s > 0.01)
            root.pickH = hsv.h
        root.pickS = hsv.s
        root.pickV = hsv.v
        if (!swatchHexInput.activeFocus)
            swatchHexInput.text = root.editingHex.slice(1).toUpperCase()
        root.syncingPicker = false
    }

    onEditingIndexChanged: root.syncPickerFromEditing()
    onEditingHexChanged: {
        if (!svPickerMouse.pressed && !huePickerMouse.pressed)
            root.syncPickerFromEditing()
    }

    function applyPickedSwatchHsv() {
        if (root.syncingPicker || root.editingIndex < 0)
            return
        const hex = root.hsvToHex(root.pickH, root.pickS, root.pickV)
        PaletteService.setColor(root.editingIndex, hex)
        if (!swatchHexInput.activeFocus)
            swatchHexInput.text = hex.slice(1).toUpperCase()
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function openOn(screen) {
        if (screen)
            targetScreen = screen
        open = true
    }

    function close() {
        open = false
    }

    function toggleOn(screen) {
        if (open && (!screen || screen === targetScreen))
            close()
        else
            openOn(screen)
    }

    // (`ipc call palette toggle | show | hide | shuffle` and PaletteService.requestOpen()
    // are answered in shell.qml, by the entry point that builds this tool on demand.)

    // Tells the desktop widget (PaletteWidget.qml) the tool is open, so only one of them
    // reads the picture for the same colours.
    Binding {
        target: PaletteService
        property: "toolOpen"
        value: root.open
    }

    // Where the music cover comes from (the bar, the dock and the lockscreen each have
    // their own MediaSource too).
    MediaSource {
        id: media
    }

    PaletteExtractor {
        id: extractor
        kind: PaletteService.source
        active: root.open
        media: media
    }

    // Same enter / exit shape as the cheatsheet and the Overview.
    property real openT: 0
    property real closeT: 0

    NumberAnimation {
        id: enterAnim
        target: root
        property: "openT"
        to: 1
        duration: 240
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "closeT"
        from: 0
        to: 1
        duration: 150
        easing.type: Easing.OutQuad
        onStopped: {
            root.closing = false
            root.closeT = 0
            root.openT = 0
        }
    }

    onOpenChanged: {
        if (open) {
            exitAnim.stop()
            root.closing = false
            enterAnim.restart()
        } else {
            enterAnim.stop()
            root.closing = true
            exitAnim.restart()
        }
    }

    Timer {
        id: copiedAllTimer
        interval: 1000
        onTriggered: root.copiedAll = false
    }

    // ===== The window =====
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.closing
        color: "transparent"

        // Full-screen overlay so a click outside the card reaches us and closes it.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekaipop-palette"

        ScaleHost {
            anchors.fill: parent
            factor: ShellScale.forScreen(root.targetScreen)

            Item {
                id: overlayRoot
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: root.close()
                Keys.onSpacePressed: PaletteService.shuffle()

                // Click outside the card closes it. Bottom of the stack so everything
                // with its own MouseArea takes the click instead.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // All-but-invisible layer, same as the cheatsheet: the surface is still
                // drawn and catches clicks, the desktop stays put.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colDeep
                    opacity: 0.001
                }

                Item {
                    id: content

                    readonly property real pad: 24

                    width: 720
                    height: column.implicitHeight + 2 * content.pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(16, Math.round((overlayRoot.height - content.height) / 2))

                    opacity: Math.min(1, root.openT) * (1 - root.closeT)
                    transform: Translate { y: (1 - Math.min(1, root.openT)) * 20 - 12 * root.closeT }

                    // the card: hard shadow straight down, outline, fill
                    Rectangle {
                        x: Theme.edgy ? 3 : 0
                        y: Theme.shadowOffset + 2
                        width: parent.width
                        height: parent.height
                        radius: Theme.edgy ? Theme.radiusOuter : 22
                        color: Theme.lineShadow
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.edgy ? Theme.radiusOuter : 22
                        color: Theme.edgy ? Theme.hudSurface : Theme.surface
                        border.width: Theme.borderWidth
                        border.color: Theme.edgy ? Theme.accentFrame : Theme.line
                        antialiasing: true
                        clip: true

                        CyberStripe {
                            visible: Theme.edgy
                            anchors.fill: parent
                            anchors.margins: 8
                            mode: "grid"
                            color: Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, 0.08)
                            gap: 18
                        }

                        // Cyberdeck corner accent bars
                        Rectangle {
                            visible: Theme.edgy
                            x: 0; y: 0; width: 28; height: 4
                            color: Theme.accentCyan
                        }
                        Rectangle {
                            visible: Theme.edgy
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 36; height: 4
                            color: Theme.accentYellow
                        }

                        // a click on the card is not a click outside it
                        MouseArea {
                            anchors.fill: parent
                        }
                    }

                    Column {
                        id: column
                        x: content.pad
                        y: content.pad
                        width: content.width - 2 * content.pad
                        spacing: 16

                        // ===== header =====
                        Item {
                            width: parent.width
                            height: 34

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    visible: Theme.edgy
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: Theme.radiusInner
                                    color: Theme.hudSurface
                                    border.width: 1
                                    border.color: Theme.accentFrame

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "palette"
                                        size: 20
                                        color: Theme.accentCyan
                                    }
                                }

                                MaterialIcon {
                                    visible: !Theme.edgy
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "palette"
                                    size: 28
                                    color: Theme.ink
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Theme.edgy ? "PALETTE // STUDIO" : "Palette"
                                    color: Theme.edgy ? Theme.accentCyan : Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.edgy ? 21 : 24
                                    font.weight: Font.ExtraBold
                                    font.styleName: Theme.fontStyleBold
                                    font.letterSpacing: Theme.edgy ? 0.8 : 0
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                // says out loud whether the theme is being touched
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 28
                                    width: statusRow.implicitWidth + 20
                                    radius: Theme.edgy ? Theme.radiusInner : 14
                                    antialiasing: true
                                    color: Theme.edgy
                                        ? (PaletteService.applied
                                            ? Qt.rgba(Theme.accentGreen.r, Theme.accentGreen.g, Theme.accentGreen.b, 0.18)
                                            : Theme.hudSurface)
                                        : (PaletteService.applied ? Theme.accentMint : Theme.surfaceHover)
                                    border.width: Theme.edgy ? 1 : 2
                                    border.color: Theme.edgy
                                        ? (PaletteService.applied ? Theme.accentGreen : Theme.accentFrame)
                                        : Theme.line

                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Row {
                                        id: statusRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: PaletteService.applied ? "check_circle" : "visibility"
                                            size: 16
                                            color: Theme.edgy
                                                ? (PaletteService.applied ? Theme.accentGreen : Theme.accentYellow)
                                                : (PaletteService.applied ? Theme.colBorder : Theme.ink)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Theme.edgy
                                                ? (PaletteService.applied ? "THEME SYNCED" : "PREVIEW ONLY : UNCHANGED")
                                                : (PaletteService.applied ? "Applied to the theme" : "Preview only, theme unchanged")
                                            color: Theme.edgy
                                                ? (PaletteService.applied ? Theme.accentGreen : Theme.accentYellow)
                                                : (PaletteService.applied ? Theme.colBorder : Theme.ink)
                                            font.family: Theme.edgy ? Theme.monoFontFamily : Theme.fontFamily
                                            font.pixelSize: Theme.edgy ? 11 : 12
                                            font.weight: Font.ExtraBold
                                            font.styleName: Theme.fontStyleBold
                                        }
                                    }
                                }

                                Rectangle {
                                    id: closeBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    radius: Theme.edgy ? Theme.radiusInner : 15
                                    antialiasing: true
                                    color: closeMouse.containsMouse ? Theme.surfaceTint : (Theme.edgy ? Theme.hudSurface : Theme.surfaceHover)
                                    border.width: Theme.edgy ? 1 : 2
                                    border.color: Theme.edgy ? Theme.accentFrame : Theme.line

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 18
                                        color: Theme.edgy ? Theme.accentCyan : Theme.ink
                                    }

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.close()
                                    }
                                }
                            }

                            CyberStripe {
                                visible: Theme.edgy
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -6
                                height: 3
                                mode: "stripes"
                                fillRatio: PaletteService.applied ? 1.0 : 0.72
                                color: Theme.accentCyan
                                altColor: Theme.accentYellow
                                trackColor: Qt.rgba(Theme.accentFrame.r, Theme.accentFrame.g, Theme.accentFrame.b, 0.28)
                                stripeWidth: 6
                                gap: 3
                            }
                        }

                        // ===== where the colours come from =====
                        Item {
                            width: parent.width
                            height: 34

                            SegmentSwitch {
                                id: tabs
                                width: 330
                                height: 34
                                options: [
                                    { id: "wallpaper", label: "Wallpaper" },
                                    { id: "music", label: "Music" },
                                    { id: "random", label: "Random" }
                                ]
                                current: PaletteService.source
                                onPicked: id => {
                                    if (id === "random") {
                                        PaletteService.shuffle()
                                    } else if (id === PaletteService.source) {
                                        extractor.push()
                                    } else {
                                        PaletteService.setSource(id)
                                    }
                                }
                            }

                            Text {
                                anchors.left: tabs.right
                                anchors.leftMargin: 16
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                text: {
                                    if (PaletteService.source === "random")
                                        return PaletteService.scheme !== "" ? ("Harmony: " + PaletteService.scheme + ", Space shuffles") : "Space shuffles"
                                    if (extractor.problem !== "")
                                        return extractor.problem
                                    return PaletteService.source === "music" ? "From the cover of the playing track" : "From the wallpaper on screen"
                                }
                            }
                        }

                        // ===== the swatches =====
                        Row {
                            id: swatches
                            width: parent.width
                            spacing: (width - 5 * 124) / 4

                            Repeater {
                                id: swatchRepeater
                                model: 5

                                delegate: PaletteSwatch {
                                    required property int index

                                    width: 124
                                    hex: PaletteService.colors[index] ?? "#000000"
                                    locked: PaletteService.locks[index] === true
                                    editable: true
                                    selected: root.editingIndex === index
                                    onCopyRequested: {
                                        if (PaletteService.copy(hex))
                                            flashCopied()
                                    }
                                    onLockToggled: PaletteService.toggleLock(index)
                                    onEditRequested: {
                                        root.editingIndex = (root.editingIndex === index) ? -1 : index
                                    }
                                }
                            }
                        }

                        // ===== inline swatch colour picker =====
                        Rectangle {
                            id: pickerBar
                            visible: root.editingIndex >= 0
                            width: parent.width
                            height: 92
                            radius: Theme.edgy ? Theme.radiusInner : 14
                            color: Theme.surfaceHover
                            border.width: Theme.borderWidth
                            border.color: Theme.line

                            Row {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                // Swatch badge + label
                                Column {
                                    width: 96
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: "SWATCH #" + (root.editingIndex + 1)
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.ExtraBold
                                        font.styleName: Theme.fontStyleBold
                                    }

                                    Rectangle {
                                        width: 92
                                        height: 28
                                        radius: Theme.edgy ? 2 : 7
                                        color: Theme.surface
                                        border.width: swatchHexInput.activeFocus ? 2 : 1.5
                                        border.color: Theme.line

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 3
                                                color: root.editingHex
                                                border.width: 1
                                                border.color: Theme.line
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "#"
                                                color: Theme.inkSub
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                            }

                                            TextInput {
                                                id: swatchHexInput
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 52
                                                color: Theme.ink
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                maximumLength: 6
                                                validator: RegularExpressionValidator {
                                                    regularExpression: /[0-9a-fA-F]{0,6}/
                                                }
                                                onTextEdited: {
                                                    const h = PM.norm(text)
                                                    if (h !== "" && text.length === 6)
                                                        PaletteService.setColor(root.editingIndex, h)
                                                }
                                                onAccepted: {
                                                    const h = PM.norm(text)
                                                    if (h !== "")
                                                        PaletteService.setColor(root.editingIndex, h)
                                                    focus = false
                                                }
                                            }
                                        }
                                    }
                                }

                                // 2D Saturation / Value Box
                                Item {
                                    id: svPickerBox
                                    width: 180
                                    height: 70
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.edgy ? 2 : 6
                                        color: root.hsvToHex(root.pickH, 1, 1)
                                    }

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

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.edgy ? 2 : 6
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#00000000" }
                                            GradientStop { position: 1.0; color: "#ff000000" }
                                        }
                                        border.width: 1.5
                                        border.color: Theme.line
                                    }

                                    Rectangle {
                                        x: Math.round(root.pickS * (svPickerBox.width - 4)) - 3
                                        y: Math.round((1 - root.pickV) * (svPickerBox.height - 4)) - 3
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: root.editingHex
                                        border.width: 2
                                        border.color: root.pickV > 0.55 ? "#000000" : "#ffffff"
                                    }

                                    MouseArea {
                                        id: svPickerMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.CrossCursor
                                        function updateSv(mx, my) {
                                            root.pickS = Math.max(0, Math.min(1, mx / svPickerBox.width))
                                            root.pickV = Math.max(0, Math.min(1, 1 - (my / svPickerBox.height)))
                                            root.applyPickedSwatchHsv()
                                        }
                                        onPressed: mouse => updateSv(mouse.x, mouse.y)
                                        onPositionChanged: mouse => {
                                            if (pressed)
                                                updateSv(mouse.x, mouse.y)
                                        }
                                    }
                                }

                                // Hue Bar
                                Item {
                                    id: huePickerBox
                                    width: 18
                                    height: 70
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.edgy ? 2 : 6
                                        border.width: 1.5
                                        border.color: Theme.line
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

                                    Rectangle {
                                        x: -1
                                        y: Math.round((root.pickH / 360) * (huePickerBox.height - 6))
                                        width: huePickerBox.width + 2
                                        height: 6
                                        radius: 2
                                        color: "#ffffff"
                                        border.width: 1.5
                                        border.color: "#000000"
                                    }

                                    MouseArea {
                                        id: huePickerMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function updateHue(my) {
                                            root.pickH = Math.max(0, Math.min(359.9, (my / huePickerBox.height) * 360))
                                            root.applyPickedSwatchHsv()
                                        }
                                        onPressed: mouse => updateHue(mouse.y)
                                        onPositionChanged: mouse => {
                                            if (pressed)
                                                updateHue(mouse.y)
                                        }
                                    }
                                }

                                // Quick Cyberpunk Presets
                                Grid {
                                    columns: 6
                                    spacing: 5
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: [
                                            "#00f0ff", "#ff2a55", "#fcee0a", "#00ff7f", "#38bdf8", "#a855f7",
                                            "#ff9e2c", "#ff2a85", "#1e3448", "#0b1622", "#070b12", "#e6e6e6"
                                        ]

                                        Rectangle {
                                            required property string modelData
                                            width: 22
                                            height: 22
                                            radius: Theme.edgy ? 2 : 6
                                            color: modelData
                                            border.width: 1.5
                                            border.color: Theme.line

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: PaletteService.setColor(root.editingIndex, modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // Close inline picker button
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                width: 22
                                height: 22
                                radius: Theme.edgy ? 2 : 7
                                color: Theme.surface
                                border.width: 1.5
                                border.color: Theme.line

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 13
                                    color: Theme.ink
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editingIndex = -1
                                }
                            }
                        }

                        // ===== actions =====
                        Item {
                            width: parent.width
                            height: 37

                            Row {
                                spacing: 10

                                PaletteButton {
                                    icon: "casino"
                                    label: "Shuffle"
                                    onClicked: PaletteService.shuffle()
                                }

                                PaletteButton {
                                    icon: "favorite"
                                    label: PaletteService.isFavorite ? "Saved" : "Save"
                                    lit: PaletteService.isFavorite
                                    onClicked: PaletteService.toggleFavorite()
                                }

                                PaletteButton {
                                    icon: root.copiedAll ? "check" : "content_copy"
                                    label: root.copiedAll ? "Copied" : "Copy all"
                                    onClicked: {
                                        PaletteService.copyAll()
                                        root.copiedAll = true
                                        copiedAllTimer.restart()
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                spacing: 10

                                PaletteButton {
                                    visible: PaletteService.canUndo
                                    icon: "undo"
                                    label: "Undo"
                                    onClicked: PaletteService.undo()
                                }

                                // the ONE button that changes the theme
                                PaletteButton {
                                    primary: true
                                    enabled: !PaletteService.applied
                                    icon: PaletteService.applied ? "check" : "format_paint"
                                    label: PaletteService.applied ? "Applied" : "Apply to theme"
                                    onClicked: PaletteService.apply()
                                }
                            }
                        }

                        // ===== live preview + how it maps =====
                        Item {
                            width: parent.width
                            height: preview.height

                            PalettePreview {
                                id: preview
                                width: 440
                                height: 200
                                colors: PaletteService.colors
                            }

                            Column {
                                anchors.left: preview.right
                                anchors.leftMargin: 16
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 9

                                Text {
                                    text: "WHAT THE SHELL WOULD WEAR"
                                    color: Theme.inkSub
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.ExtraBold
                                    font.letterSpacing: 0.8
                                }

                                Repeater {
                                    model: [
                                        { label: "Outline and text", key: "border" },
                                        { label: "Accent", key: "A" },
                                        { label: "Second accent", key: "B" },
                                        { label: "Dark tone", key: "deep" },
                                        { label: "Hover wash", key: "hoverTint" }
                                    ]

                                    delegate: Row {
                                        required property var modelData
                                        spacing: 8

                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: Theme.edgy ? 2 : 7
                                            antialiasing: true
                                            color: root.shell[modelData.key]
                                            border.width: 2
                                            border.color: Theme.edgy ? Theme.accentFrame : Theme.line
                                            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: modelData.label
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.ExtraBold
                                            }

                                            Text {
                                                text: String(root.shell[modelData.key]).toUpperCase()
                                                color: Theme.inkSub
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== favourites =====
                        Column {
                            width: parent.width
                            spacing: 8

                            Text {
                                text: "FAVOURITES" + (PaletteService.favorites.length > 0 ? " (" + PaletteService.favorites.length + ")" : "")
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.ExtraBold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                visible: PaletteService.favorites.length === 0
                                width: parent.width
                                text: "Press Save to keep a palette here. Clicking one brings it back onto the strip; your theme stays as it is until you Apply."
                                wrapMode: Text.WordWrap
                                color: Theme.inkSub
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Flickable {
                                id: favFlick
                                visible: PaletteService.favorites.length > 0
                                width: parent.width
                                height: 44
                                contentWidth: favRow.width
                                contentHeight: height
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                clip: contentWidth > width

                                // a plain wheel scrolls the row sideways
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: event => {
                                        const d = Theme.wheelPx(event, true)
                                        favFlick.contentX = Math.max(0, Math.min(Math.max(0, favFlick.contentWidth - favFlick.width), favFlick.contentX - d))
                                    }
                                }

                                Row {
                                    id: favRow
                                    y: 4
                                    spacing: 10

                                    Repeater {
                                        model: PaletteService.favorites

                                        delegate: PaletteFavorite {
                                            required property var modelData

                                            colors: modelData.colors
                                            current: PM.sameColors(modelData.colors, PaletteService.colors)
                                            onPicked: PaletteService.useFavorite(modelData.colors)
                                            onRemoved: PaletteService.removeFavorite(modelData.colors)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
