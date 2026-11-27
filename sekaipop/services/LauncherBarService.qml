pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// State for the "Launcher" screen-edge bar/dock hybrid widget (LauncherBar.qml).
// Holds the list of application icons dragged onto it, in order, and persists
// them to ~/.local/state/sekaipop/launcher-bar.json (scripts/state/launcherbar-state.sh).
//
// Each entry in `apps` is:
//   { id: "kitty", name: "Kitty", icon: "kitty", exec: "kitty" }
Singleton {
    id: root

    property bool loaded: false
    property bool shown: false
    property string screenName: ""
    property real posX: -1
    property real posY: -1
    property real posScale: 0

    // [{ id, name, icon, exec }]
    property var apps: []

    readonly property string script: Directories.script("state/launcherbar-state.sh")

    function copy(list) {
        return JSON.parse(JSON.stringify(list || []))
    }

    function setShown(value) {
        root.shown = value === true
        root.persist()
    }

    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function indexOfApp(id) {
        if (!id)
            return -1
        const key = String(id).toLowerCase()
        return root.apps.findIndex(a => String(a.id || "").toLowerCase() === key)
    }

    function hasApp(id) {
        return root.indexOfApp(id) >= 0
    }

    function addApp(raw, at) {
        if (!raw)
            return false
        const id = String(raw.id || raw.class || raw.name || "").trim()
        const name = String(raw.name || id || "App").trim()
        const icon = String(raw.icon || raw.iconName || "").trim()
        const exec = String(raw.exec || "").trim()
        if (id === "" && name === "")
            return false
        const normId = id !== "" ? id : name.toLowerCase().replace(/\s+/g, "-")
        const existingIdx = root.indexOfApp(normId)
        const next = root.copy(root.apps)
        const item = {
            id: normId,
            name: name,
            icon: icon,
            exec: exec
        }
        if (existingIdx >= 0) {
            next.splice(existingIdx, 1)
            let target = (at === undefined || at < 0 || at > next.length) ? existingIdx : at
            if (at !== undefined && at > existingIdx)
                target = Math.max(0, Math.min(next.length, at - 1))
            next.splice(target, 0, item)
        } else {
            const i = (at === undefined || at < 0 || at > next.length) ? next.length : at
            next.splice(i, 0, item)
        }
        root.apps = next
        root.persist()
        return true
    }

    function removeAt(index) {
        if (index < 0 || index >= root.apps.length)
            return false
        const next = root.copy(root.apps)
        next.splice(index, 1)
        root.apps = next
        root.persist()
        return true
    }

    function removeApp(id) {
        const idx = root.indexOfApp(id)
        if (idx < 0)
            return false
        return root.removeAt(idx)
    }

    function move(from, to) {
        const n = root.apps.length
        if (from < 0 || from >= n || to < 0 || to >= n || from === to)
            return false
        const next = root.copy(root.apps)
        const item = next.splice(from, 1)[0]
        next.splice(to, 0, item)
        root.apps = next
        root.persist()
        return true
    }

    function clear() {
        if (root.apps.length === 0)
            return
        root.apps = []
        root.persist()
    }

    // Launch an app entry from the Launcher bar.
    function launch(item) {
        if (!item)
            return
        const id = String(item.id || "").toLowerCase()
        const name = String(item.name || "").toLowerCase()
        const entries = DesktopEntries.applications ? DesktopEntries.applications.values : []
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            if (!e)
                continue
            if ((e.id && String(e.id).toLowerCase() === id)
                    || (e.id && String(e.id).toLowerCase() === id + ".desktop")
                    || (e.name && String(e.name).toLowerCase() === name)) {
                e.execute()
                return
            }
        }
        if (item.exec && String(item.exec).trim() !== "") {
            Quickshell.execDetached(["sh", "-c", String(item.exec)])
            return
        }
        if (item.id && String(item.id).trim() !== "")
            Quickshell.execDetached(["gtk-launch", String(item.id)])
    }

    // Handle external Wayland drops (.desktop files, URLs, or app names).
    property int pendingDropAt: -1

    function addDrop(drop, atIndex) {
        if (!drop)
            return
        const urls = []
        if (drop.urls && drop.urls.length > 0) {
            for (let i = 0; i < drop.urls.length; i++)
                urls.push(String(drop.urls[i]))
        } else if (drop.text && String(drop.text).trim() !== "") {
            for (const line of String(drop.text).split(/\r?\n/)) {
                const t = line.trim()
                if (t !== "" && !t.startsWith("#"))
                    urls.push(t)
            }
        }
        if (urls.length === 0)
            return

        const filePaths = []
        const entries = DesktopEntries.applications ? DesktopEntries.applications.values : []
        let insertAt = (atIndex === undefined || atIndex < 0) ? root.apps.length : atIndex

        for (const rawUrl of urls) {
            const clean = decodeURIComponent(String(rawUrl).replace(/^file:\/\//, "")).trim()
            const base = clean.slice(clean.lastIndexOf("/") + 1).replace(/\.desktop$/i, "")
            let matched = null
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i]
                if (!e)
                    continue
                const eid = String(e.id || "").replace(/\.desktop$/i, "")
                if (eid.toLowerCase() === base.toLowerCase()
                        || String(e.name || "").toLowerCase() === base.toLowerCase()) {
                    matched = e
                    break
                }
            }
            if (matched) {
                root.addApp({
                    id: String(matched.id || base).replace(/\.desktop$/i, ""),
                    name: matched.name || base,
                    icon: matched.icon || "",
                    exec: ""
                }, insertAt)
                insertAt++
            } else {
                filePaths.push(clean)
            }
        }

        if (filePaths.length > 0 && !desktopParser.running) {
            root.pendingDropAt = insertAt
            desktopParser.command = ["sh", root.script, "parse-desktop"].concat(filePaths)
            desktopParser.running = true
        }
    }

    Process {
        id: desktopParser
        stdout: StdioCollector {
            onStreamFinished: {
                let at = root.pendingDropAt < 0 ? root.apps.length : root.pendingDropAt
                for (const line of text.split("\n")) {
                    if (!line)
                        continue
                    const parts = line.split("\t")
                    if (parts.length >= 2) {
                        root.addApp({
                            id: parts[0],
                            name: parts[1],
                            icon: parts[2] || "",
                            exec: parts[3] || ""
                        }, at)
                        at++
                    }
                }
            }
        }
    }

    // ===== persistence =====
    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            apps: root.apps
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            if (typeof s.shown === "boolean")
                root.shown = s.shown
            if (Array.isArray(s.apps)) {
                root.apps = s.apps.filter(a => a && (a.id || a.name)).map(a => ({
                    id: String(a.id || a.name),
                    name: String(a.name || a.id),
                    icon: String(a.icon || ""),
                    exec: String(a.exec || "")
                }))
            }
        } catch (e) {
            // No file yet or unreadable: keep defaults.
        }
        root.loaded = true
    }

    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: saver.save(root.snapshot())
    }

    Process {
        id: saver
        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
