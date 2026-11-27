pragma Singleton
import QtQuick
import Quickshell

// Coordinates dragging an application icon from the Cyberdeck Apps screen
// (LauncherFace.qml / AppResultRow.qml) onto the screen-edge Launcher bar
// (LauncherBar.qml), with a floating overlay icon (AppDragGhost.qml).
Singleton {
    id: root

    property bool active: false
    // { id, name, icon, exec }
    property var app: null
    property string screenName: ""
    // Cursor position in screen pixels of `screenName`.
    property real cursorX: 0
    property real cursorY: 0
    // True when the cursor is currently over a LauncherBar drop zone.
    property bool overLauncher: false
    property int targetIndex: -1

    property var targets: []

    function registerTarget(win) {
        if (!win || root.targets.indexOf(win) >= 0)
            return
        const next = root.targets.slice()
        next.push(win)
        root.targets = next
    }

    function unregisterTarget(win) {
        const next = root.targets.filter(t => t !== win)
        if (next.length !== root.targets.length)
            root.targets = next
    }

    // Converts a local point (x, y) inside `item` to full screen coordinates on its monitor.
    function toScreenPoint(item, x, y) {
        if (!item)
            return { x: x, y: y }
        const p = item.mapToItem(null, x, y)
        const w = item.QsWindow ? item.QsWindow.window : null
        if (!w || !w.screen)
            return { x: p.x, y: p.y }
        const sw = w.screen.width
        const sh = w.screen.height
        const ww = w.width || sw
        const wh = w.height || sh
        const bleed = typeof w.bleed === "number" ? Math.ceil(w.bleed) : 0
        const ox = (w.anchors && !w.anchors.left && !w.anchors.right) ? Math.round((sw - ww) / 2) : 0
        const oy = (w.anchors && w.anchors.bottom && !w.anchors.top) ? Math.round(sh - wh + bleed) : 0
        return { x: ox + p.x, y: oy + p.y }
    }

    function normalizeApp(raw) {
        if (!raw)
            return null
        const entry = raw.app ? raw.app : raw
        const id = String(raw.id || entry.id || raw.class || raw.name || "").trim()
        const name = String(raw.name || entry.name || id || "App").trim()
        const icon = String(raw.icon || entry.icon || "").trim()
        const exec = String(raw.exec || (entry.command ? entry.command.join(" ") : "") || "").trim()
        if (id === "" && name === "")
            return null
        return {
            id: id !== "" ? id : name.toLowerCase().replace(/\s+/g, "-"),
            name: name,
            icon: icon,
            exec: exec
        }
    }

    function startDrag(rawApp, screenName, screenX, screenY) {
        const norm = root.normalizeApp(rawApp)
        if (!norm)
            return false
        // Make sure the Launcher bar is visible if the user drags an app to add to it.
        if (!LauncherBarService.shown)
            LauncherBarService.setShown(true)
        root.app = norm
        root.screenName = screenName || ""
        root.cursorX = screenX
        root.cursorY = screenY
        root.overLauncher = false
        root.targetIndex = -1
        root.active = true
        root.updateDrag(screenX, screenY)
        return true
    }

    function updateDrag(screenX, screenY) {
        if (!root.active)
            return
        root.cursorX = screenX
        root.cursorY = screenY
        let hit = false
        let idx = -1
        for (const t of root.targets) {
            if (!t || !t.screen || (root.screenName !== "" && t.screen.name !== root.screenName))
                continue
            const res = t.testAppDrag(screenX, screenY)
            if (res && res.hit) {
                hit = true
                idx = res.index
            }
        }
        root.overLauncher = hit
        root.targetIndex = idx
    }

    function endDrag() {
        if (!root.active)
            return false
        const dropped = root.overLauncher && root.app !== null
        const appToAdd = root.app
        const atIdx = root.targetIndex
        root.active = false
        root.app = null
        root.overLauncher = false
        root.targetIndex = -1
        for (const t of root.targets) {
            if (t && t.clearExternalDrag)
                t.clearExternalDrag()
        }
        if (dropped)
            LauncherBarService.addApp(appToAdd, atIdx)
        return dropped
    }

    function cancelDrag() {
        if (!root.active)
            return
        root.active = false
        root.app = null
        root.overLauncher = false
        root.targetIndex = -1
        for (const t of root.targets) {
            if (t && t.clearExternalDrag)
                t.clearExternalDrag()
        }
    }
}
