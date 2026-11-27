import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.bar
import qs.modules.sekai.editMode
import qs.modules.sekai.launcher

// The "Launcher" widget: a hybrid between the Dock and the Bar, anchored to a
// screen edge. Its sole purpose is holding application icons that you drag onto
// it (from the Cyberdeck Apps screen or from a file manager), launching them on
// click, reordering them by dragging along the strip, and removing them by
// dragging them off the strip (or right-clicking).
PanelWindow {
    id: launcherWin

    readonly property var mt: Theme.of(screen)

    // { screen, position, perMonitor }
    required property var modelData
    screen: modelData.screen

    // QuickPanel reference from shell.qml so the "+" key can open the Apps screen.
    property var quickPanel: null

    readonly property string position: modelData.position
    readonly property bool vertical: launcherWin.position === "left" || launcherWin.position === "right"
    readonly property string look: {
        const v = SettingsService.get("launcherbar.style")
        return (v === "bar" || v === "transparent" || v === "capsule") ? v : "float"
    }
    readonly property bool fullBar: launcherWin.look === "bar"
    readonly property bool capKeys: launcherWin.look === "capsule"
    readonly property string hideMode: {
        const m = SettingsService.get("launcherbar.hideMode")
        return (m === "auto" || m === "reserve") ? m : "off"
    }

    readonly property real uiScale: ShellScale.forScreen(launcherWin.screen)
    readonly property real screenW: (launcherWin.screen ? launcherWin.screen.width : 1920) / launcherWin.uiScale
    readonly property real screenH: (launcherWin.screen ? launcherWin.screen.height : 1080) / launcherWin.uiScale

    readonly property int iconSize: Math.max(24, Math.min(64, Math.round(SettingsService.get("launcherbar.iconSize"))))
    readonly property int keySize: launcherWin.iconSize + 14
    readonly property int iconGap: 10
    readonly property int padAlong: 14
    readonly property int padAcross: 10
    readonly property int edgeMargin: launcherWin.fullBar ? 0 : 8

    readonly property var apps: LauncherBarService.apps
    readonly property bool showAddKey: SettingsService.flag("launcherbar.addButton") || launcherWin.apps.length === 0

    // ===== internal drag (reorder or drag off to remove) =====
    property bool dragging: false
    property int dragIdx: -1
    property real dragAlong: 0
    property int dragTarget: -1
    property bool dragRemove: false
    readonly property real removeDistance: 52

    // ===== incoming drag (from Cyberdeck Apps screen or external DropArea) =====
    property bool externalDragOver: false
    property int externalInsertIdx: -1

    readonly property bool editing: launcherWin.screen !== null && EditMode.editing(launcherWin.screen.name)
    property bool peeked: false

    Timer {
        id: peekTimer
        interval: 2200
        onTriggered: launcherWin.peeked = false
    }

    function peek() {
        launcherWin.peeked = true
        peekTimer.restart()
    }

    readonly property bool revealed: launcherWin.hideMode !== "auto"
        || launcherWin.editing
        || launcherWin.peeked
        || launcherWin.dragging
        || launcherWin.externalDragOver
        || AppDragService.active
        || dropArea.containsDrag
        || stripHover.hovered
        || edgeHover.hovered

    property real hideSlide: launcherWin.revealed ? 0 : 1
    Behavior on hideSlide {
        NumberAnimation {
            duration: 240
            easing.type: launcherWin.revealed ? Easing.OutCubic : Easing.InCubic
        }
    }

    // ===== geometry =====
    // Slot count includes the dragged-in preview gap when an external app is hovering over the strip.
    readonly property int appCount: launcherWin.apps.length
    readonly property bool hasInsertGap: (launcherWin.externalDragOver || dropArea.containsDrag) && launcherWin.externalInsertIdx >= 0
    readonly property int visualAppSlots: launcherWin.appCount + (launcherWin.hasInsertGap ? 1 : 0)
    readonly property int totalSlots: launcherWin.visualAppSlots + (launcherWin.showAddKey ? 1 : 0)

    readonly property real contentLength: Math.max(launcherWin.keySize,
        launcherWin.totalSlots * launcherWin.keySize + Math.max(0, launcherWin.totalSlots - 1) * launcherWin.iconGap)
    readonly property real pillLength: launcherWin.fullBar
        ? (launcherWin.vertical ? launcherWin.screenH : launcherWin.screenW)
        : (launcherWin.contentLength + launcherWin.padAlong * 2)
    readonly property real pillThickness: launcherWin.keySize + launcherWin.padAcross * 2

    readonly property real pillW: launcherWin.vertical ? launcherWin.pillThickness : launcherWin.pillLength
    readonly property real pillH: launcherWin.vertical ? launcherWin.pillLength : launcherWin.pillThickness

    // Where the pill sits in design pixels on the screen.
    readonly property real baseX: {
        if (launcherWin.position === "left")
            return launcherWin.edgeMargin
        if (launcherWin.position === "right")
            return launcherWin.screenW - launcherWin.pillW - launcherWin.edgeMargin
        return Math.round((launcherWin.screenW - launcherWin.pillW) / 2)
    }
    readonly property real baseY: {
        if (launcherWin.position === "top")
            return launcherWin.edgeMargin
        if (launcherWin.position === "bottom")
            return launcherWin.screenH - launcherWin.pillH - launcherWin.edgeMargin
        return Math.round((launcherWin.screenH - launcherWin.pillH) / 2)
    }

    readonly property real slideDist: launcherWin.pillThickness + launcherWin.edgeMargin + 10
    readonly property real slideDx: launcherWin.position === "left" ? -launcherWin.slideDist * launcherWin.hideSlide
        : (launcherWin.position === "right" ? launcherWin.slideDist * launcherWin.hideSlide : 0)
    readonly property real slideDy: launcherWin.position === "top" ? -launcherWin.slideDist * launcherWin.hideSlide
        : (launcherWin.position === "bottom" ? launcherWin.slideDist * launcherWin.hideSlide : 0)

    // Offset inside `pill` where the icon row starts (centered when `fullBar` is true).
    readonly property real rowStartOffset: Math.round((launcherWin.pillLength - launcherWin.contentLength) / 2)

    function slotOffset(visualSlot) {
        return launcherWin.rowStartOffset + visualSlot * (launcherWin.keySize + launcherWin.iconGap)
    }

    function visualSlotForIndex(i) {
        let slot = i
        if (launcherWin.dragging && launcherWin.dragIdx >= 0 && !launcherWin.dragRemove) {
            const from = launcherWin.dragIdx
            const to = launcherWin.dragTarget
            if (i === from)
                slot = to
            else if (from < to && i > from && i <= to)
                slot = i - 1
            else if (to < from && i >= to && i < from)
                slot = i + 1
        } else if (launcherWin.hasInsertGap && i >= launcherWin.externalInsertIdx) {
            slot = i + 1
        }
        return slot
    }

    function indexFromAlong(along) {
        const n = launcherWin.appCount
        if (n <= 0)
            return 0
        for (let i = 0; i < n; i++) {
            const center = launcherWin.rowStartOffset + i * (launcherWin.keySize + launcherWin.iconGap) + launcherWin.keySize / 2
            if (along < center)
                return i
        }
        return n
    }

    // Called by AppDragService during an in-shell drag from the Cyberdeck Apps screen.
    function testAppDrag(screenX, screenY) {
        const dx = screenX / launcherWin.uiScale
        const dy = screenY / launcherWin.uiScale
        const margin = 44
        const hitX = dx >= (launcherWin.baseX - margin) && dx <= (launcherWin.baseX + launcherWin.pillW + margin)
        const hitY = dy >= (launcherWin.baseY - margin) && dy <= (launcherWin.baseY + launcherWin.pillH + margin)
        if (hitX && hitY) {
            const along = launcherWin.vertical ? (dy - launcherWin.baseY) : (dx - launcherWin.baseX)
            const idx = launcherWin.indexFromAlong(along)
            launcherWin.externalDragOver = true
            launcherWin.externalInsertIdx = idx
            return { hit: true, index: idx }
        }
        launcherWin.externalDragOver = false
        launcherWin.externalInsertIdx = -1
        return { hit: false, index: -1 }
    }

    function clearExternalDrag() {
        launcherWin.externalDragOver = false
        launcherWin.externalInsertIdx = -1
    }

    Component.onCompleted: AppDragService.registerTarget(launcherWin)
    Component.onDestruction: AppDragService.unregisterTarget(launcherWin)

    // ===== internal drag helpers =====
    function startDrag(idx, along) {
        launcherWin.dragging = true
        launcherWin.dragIdx = idx
        launcherWin.dragTarget = idx
        launcherWin.dragAlong = along
        launcherWin.dragRemove = false
    }

    function moveDrag(along, acrossOut) {
        if (!launcherWin.dragging)
            return
        launcherWin.dragAlong = along
        launcherWin.dragRemove = acrossOut > launcherWin.removeDistance
        if (launcherWin.dragRemove)
            return
        const n = launcherWin.appCount
        let best = launcherWin.dragIdx
        let bestDist = 1e9
        for (let i = 0; i < n; i++) {
            const center = launcherWin.rowStartOffset + i * (launcherWin.keySize + launcherWin.iconGap) + launcherWin.keySize / 2
            const d = Math.abs(along - center)
            if (d < bestDist) {
                bestDist = d
                best = i
            }
        }
        launcherWin.dragTarget = best
    }

    function endDrag() {
        if (!launcherWin.dragging)
            return
        const from = launcherWin.dragIdx
        const to = launcherWin.dragTarget
        const remove = launcherWin.dragRemove
        launcherWin.dragging = false
        launcherWin.dragIdx = -1
        launcherWin.dragTarget = -1
        launcherWin.dragRemove = false
        if (remove)
            LauncherBarService.removeAt(from)
        else if (from >= 0 && to >= 0 && from !== to)
            LauncherBarService.move(from, to)
    }

    // ===== Layer-shell configuration =====
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "sekaipop-launcherbar"
    WlrLayershell.layer: launcherWin.editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: (launcherWin.hideMode === "reserve" && !launcherWin.editing)
        ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: (launcherWin.hideMode === "reserve" && !launcherWin.editing)
        ? Math.round((launcherWin.pillThickness + launcherWin.edgeMargin) * launcherWin.uiScale) : 0
    color: "transparent"

    // Input mask: only the pill (or the 6px hot edge while auto-hidden) takes pointer input.
    Item {
        id: hitBox
        readonly property real hotDepth: 8
        x: {
            if (launcherWin.editing)
                return 0
            if (!launcherWin.revealed && launcherWin.position === "right")
                return Math.round((launcherWin.screenW - hitBox.hotDepth) * launcherWin.uiScale)
            if (!launcherWin.revealed && launcherWin.position === "left")
                return 0
            return Math.max(0, Math.round((pillBox.x - 10) * launcherWin.uiScale))
        }
        y: {
            if (launcherWin.editing)
                return 0
            if (!launcherWin.revealed && launcherWin.position === "bottom")
                return Math.round((launcherWin.screenH - hitBox.hotDepth) * launcherWin.uiScale)
            if (!launcherWin.revealed && launcherWin.position === "top")
                return 0
            return Math.max(0, Math.round((pillBox.y - 10) * launcherWin.uiScale))
        }
        width: {
            if (launcherWin.editing)
                return 0
            if (!launcherWin.revealed && launcherWin.vertical)
                return Math.round(hitBox.hotDepth * launcherWin.uiScale)
            return Math.max(1, Math.round((pillBox.width + 20) * launcherWin.uiScale))
        }
        height: {
            if (launcherWin.editing)
                return 0
            if (!launcherWin.revealed && !launcherWin.vertical)
                return Math.round(hitBox.hotDepth * launcherWin.uiScale)
            return Math.max(1, Math.round((pillBox.height + 20) * launcherWin.uiScale))
        }
    }

    mask: Region {
        item: hitBox
    }

    // Snapshot for Edit Desktop's Widgets shelf.
    EditPreview {
        widgetId: "launcherbar"
        target: pillBox
    }

    ScaleHost {
        scale: launcherWin.uiScale

        EditStage {
            anchors.fill: parent
            screenName: launcherWin.screen ? launcherWin.screen.name : ""

            // Hot-edge hover sensor for Auto-hide mode.
            Item {
                x: launcherWin.position === "right" ? launcherWin.screenW - 8 : 0
                y: launcherWin.position === "bottom" ? launcherWin.screenH - 8 : 0
                width: launcherWin.vertical ? 8 : launcherWin.screenW
                height: launcherWin.vertical ? launcherWin.screenH : 8

                HoverHandler {
                    id: edgeHover
                }
            }

            // Main Launcher bar container
            Item {
                id: pillBox
                x: launcherWin.baseX + launcherWin.slideDx
                y: launcherWin.baseY + launcherWin.slideDy
                width: launcherWin.pillW
                height: launcherWin.pillH

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on x {
                    enabled: !launcherWin.vertical
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: launcherWin.vertical
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    id: stripHover
                }

                // External Wayland DropArea (.desktop files / executables from a file manager)
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onEntered: drag => {
                        const along = launcherWin.vertical ? drag.y : drag.x
                        launcherWin.externalInsertIdx = launcherWin.indexFromAlong(along)
                    }
                    onPositionChanged: drag => {
                        const along = launcherWin.vertical ? drag.y : drag.x
                        launcherWin.externalInsertIdx = launcherWin.indexFromAlong(along)
                    }
                    onExited: {
                        if (!launcherWin.externalDragOver)
                            launcherWin.externalInsertIdx = -1
                    }
                    onDropped: drop => {
                        const along = launcherWin.vertical ? drop.y : drop.x
                        const idx = launcherWin.indexFromAlong(along)
                        LauncherBarService.addDrop(drop, idx)
                        launcherWin.externalInsertIdx = -1
                        drop.accept(Qt.CopyAction)
                    }
                }

                // Background body (mix of Bar & Dock styling)
                Pill {
                    id: bodyPill
                    anchors.fill: parent
                    visible: launcherWin.look !== "transparent"
                    capsule: launcherWin.capKeys
                    cornerRadius: launcherWin.fullBar ? 0 : (mt.edgy ? mt.radiusInner : mt.radiusOuter)
                    ringWidth: launcherWin.capKeys ? mt.capRing : (mt.edgy ? 2 : 7)
                    fillColor: launcherWin.capKeys ? mt.capBody
                        : (mt.edgy ? mt.hudSurface : mt.barFill)
                    ringColorTop: (launcherWin.externalDragOver || dropArea.containsDrag) ? mt.accentCyan
                        : (launcherWin.capKeys ? mt.capRim : (mt.edgy ? mt.accentFrame : mt.ringWhite))
                    ringColorBottom: (launcherWin.externalDragOver || dropArea.containsDrag) ? mt.accentCyan
                        : (launcherWin.capKeys ? mt.capRim : (mt.edgy ? mt.accentFrame : mt.ringWhite))
                    shadowDx: launcherWin.fullBar ? 0 : (mt.edgy ? 2 : 0)
                    shadowDy: launcherWin.fullBar ? 0 : mt.shadowOffset

                    // Cyberpunk telemetry stripes on the frame
                    CyberStripe {
                        visible: mt.edgy && !launcherWin.capKeys
                        x: launcherWin.vertical ? 4 : 10
                        y: 3
                        width: launcherWin.vertical ? parent.width - 8 : Math.min(48, parent.width * 0.25)
                        height: 3
                        barWidth: 3
                        gap: 2
                        color: (launcherWin.externalDragOver || dropArea.containsDrag) ? mt.accentCyan : Qt.rgba(mt.accentYellow.r, mt.accentYellow.g, mt.accentYellow.b, 0.55)
                    }
                }

                // Drop-target insertion slot highlight when dragging an app over the Launcher
                Rectangle {
                    id: insertSlotIndicator
                    visible: launcherWin.hasInsertGap
                    readonly property real slotPos: launcherWin.slotOffset(Math.max(0, launcherWin.externalInsertIdx))
                    x: launcherWin.vertical ? launcherWin.padAcross : slotPos
                    y: launcherWin.vertical ? slotPos : launcherWin.padAcross
                    width: launcherWin.keySize
                    height: launcherWin.keySize
                    radius: mt.edgy ? 4 : 12
                    color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.22)
                    border.width: 2
                    border.color: mt.accentCyan
                }

                // Application Icon Keys
                Repeater {
                    model: launcherWin.apps

                    delegate: Item {
                        id: keySlot
                        required property var modelData
                        required property int index

                        readonly property bool isDragged: launcherWin.dragging && launcherWin.dragIdx === keySlot.index
                        readonly property int vSlot: launcherWin.visualSlotForIndex(keySlot.index)
                        readonly property real restOffset: launcherWin.slotOffset(keySlot.vSlot)
                        readonly property real dragOffset: Math.max(0, Math.min(launcherWin.pillLength - launcherWin.keySize,
                            launcherWin.dragAlong - launcherWin.keySize / 2))
                        readonly property real activeOffset: keySlot.isDragged ? keySlot.dragOffset : keySlot.restOffset

                        x: launcherWin.vertical ? launcherWin.padAcross : keySlot.activeOffset
                        y: launcherWin.vertical ? keySlot.activeOffset : launcherWin.padAcross
                        width: launcherWin.keySize
                        height: launcherWin.keySize
                        z: keySlot.isDragged ? 20 : 1

                        Behavior on x {
                            enabled: !keySlot.isDragged
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: !keySlot.isDragged
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }

                        readonly property string iconPath: keySlot.modelData && keySlot.modelData.icon
                            ? IconCursorService.path(keySlot.modelData.icon, true) : ""
                        readonly property bool noIcon: keySlot.iconPath === "" || keyIcon.status === Image.Error

                        Pill {
                            id: keyCap
                            anchors.fill: parent
                            capsule: launcherWin.capKeys
                            cornerRadius: mt.edgy ? 5 : 12
                            ringWidth: launcherWin.capKeys ? mt.capDotRing : (mt.edgy ? 2 : 5)
                            pressed: keyArea.pressed && !keySlot.isDragged
                            fillColor: (keySlot.isDragged && launcherWin.dragRemove)
                                ? ScrapbookTheme.tapeCoral
                                : (keyArea.containsMouse ? (mt.edgy ? Qt.lighter(mt.hudSurface, 1.35) : mt.chipFill)
                                                         : (mt.edgy ? Qt.darker(mt.hudSurface, 1.15) : mt.surface))
                            ringColorTop: (keySlot.isDragged && launcherWin.dragRemove)
                                ? ScrapbookTheme.tapeCoral
                                : (keyArea.containsMouse ? mt.accentCyan : (mt.edgy ? mt.accentFrame : mt.ringWhite))
                            ringColorBottom: ringColorTop
                            shadowDx: 0
                            shadowDy: mt.edgy ? 2 : 3
                            scale: keySlot.isDragged ? (launcherWin.dragRemove ? 0.85 : 1.08)
                                : (keyArea.containsMouse ? 1.05 : 1.0)

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }

                            IconImage {
                                id: keyIcon
                                anchors.centerIn: parent
                                width: launcherWin.iconSize
                                height: launcherWin.iconSize
                                implicitSize: launcherWin.iconSize
                                asynchronous: true
                                visible: !keySlot.noIcon && !(keySlot.isDragged && launcherWin.dragRemove)
                                source: keySlot.iconPath
                            }

                            Loader {
                                active: keySlot.noIcon && !(keySlot.isDragged && launcherWin.dragRemove)
                                anchors.centerIn: parent
                                width: launcherWin.iconSize
                                height: launcherWin.iconSize
                                sourceComponent: AppPlaceholder {
                                    size: launcherWin.iconSize
                                    name: keySlot.modelData ? keySlot.modelData.name : "App"
                                }
                            }

                            MaterialIcon {
                                visible: keySlot.isDragged && launcherWin.dragRemove
                                anchors.centerIn: parent
                                name: "delete"
                                size: Math.round(launcherWin.iconSize * 0.72)
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: keyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: keySlot.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                            property real pressX: 0
                            property real pressY: 0
                            property bool moved: false

                            onPressed: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    LauncherBarService.removeAt(keySlot.index)
                                    mouse.accepted = true
                                    return
                                }
                                keyArea.pressX = mouse.x
                                keyArea.pressY = mouse.y
                                keyArea.moved = false
                            }

                            onPositionChanged: mouse => {
                                if (!(mouse.buttons & Qt.LeftButton))
                                    return
                                const dx = mouse.x - keyArea.pressX
                                const dy = mouse.y - keyArea.pressY
                                const inPill = keySlot.mapToItem(pillBox, mouse.x, mouse.y)
                                const along = launcherWin.vertical ? inPill.y : inPill.x
                                let acrossOut = 0
                                if (launcherWin.position === "left")
                                    acrossOut = inPill.x - pillBox.width
                                else if (launcherWin.position === "right")
                                    acrossOut = -inPill.x
                                else if (launcherWin.position === "top")
                                    acrossOut = inPill.y - pillBox.height
                                else
                                    acrossOut = -inPill.y

                                if (!keyArea.moved && Math.hypot(dx, dy) > 8) {
                                    keyArea.moved = true
                                    launcherWin.startDrag(keySlot.index, along)
                                }
                                if (keyArea.moved)
                                    launcherWin.moveDrag(along, acrossOut)
                            }

                            onReleased: mouse => {
                                if (mouse.button !== Qt.LeftButton)
                                    return
                                if (keyArea.moved) {
                                    launcherWin.endDrag()
                                    keyArea.moved = false
                                } else {
                                    LauncherBarService.launch(keySlot.modelData)
                                }
                            }

                            onCanceled: {
                                if (keyArea.moved) {
                                    launcherWin.endDrag()
                                    keyArea.moved = false
                                }
                            }
                        }

                        BarTip {
                            shown: keyArea.containsMouse && (!launcherWin.dragging || keySlot.isDragged)
                            pressed: keyArea.pressed && !keySlot.isDragged
                            text: (keySlot.isDragged && launcherWin.dragRemove)
                                ? "Release to remove " + (keySlot.modelData ? keySlot.modelData.name : "")
                                : (keySlot.modelData ? keySlot.modelData.name : "")
                            barPosition: launcherWin.position
                        }
                    }
                }

                // "+" Quick-Add button (opens the Cyberdeck Apps screen so you can drag apps onto the Launcher)
                Item {
                    id: addSlot
                    visible: launcherWin.showAddKey
                    readonly property real addOffset: launcherWin.slotOffset(launcherWin.visualAppSlots)
                    x: launcherWin.vertical ? launcherWin.padAcross : addSlot.addOffset
                    y: launcherWin.vertical ? addSlot.addOffset : launcherWin.padAcross
                    width: launcherWin.keySize
                    height: launcherWin.keySize

                    Behavior on x {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Pill {
                        anchors.fill: parent
                        capsule: launcherWin.capKeys
                        cornerRadius: mt.edgy ? 5 : 12
                        ringWidth: launcherWin.capKeys ? mt.capDotRing : (mt.edgy ? 2 : 5)
                        pressed: addArea.pressed
                        fillColor: addArea.containsMouse
                            ? (mt.edgy ? Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.22) : mt.accentMint)
                            : (mt.edgy ? Qt.darker(mt.hudSurface, 1.1) : mt.chipFill)
                        ringColorTop: addArea.containsMouse ? mt.accentCyan : (mt.edgy ? mt.accentFrame : mt.ringWhite)
                        ringColorBottom: ringColorTop
                        shadowDx: 0
                        shadowDy: mt.edgy ? 2 : 3

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: Math.round(launcherWin.iconSize * 0.72)
                            weight: 700
                            color: mt.edgy ? mt.accentCyan : mt.chipInk
                        }
                    }

                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!launcherWin.quickPanel)
                                return
                            if (launcherWin.quickPanel.openAppsOn)
                                launcherWin.quickPanel.openAppsOn(launcherWin.screen)
                            else if (launcherWin.quickPanel.openLauncher)
                                launcherWin.quickPanel.openLauncher()
                        }
                    }

                    BarTip {
                        shown: addArea.containsMouse && !launcherWin.dragging
                        pressed: addArea.pressed
                        text: launcherWin.appCount === 0
                            ? "Launcher: click to open Apps and drag icons here"
                            : "Drag apps from Apps launcher or file manager"
                        barPosition: launcherWin.position
                    }
                }
            }
        }
    }
}
