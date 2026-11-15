pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Keeps all screens on the same logical workspace (1..N) when
// `workspaces.combineScreens` is enabled in Settings -> Hyprland or
// Settings -> Bar.
//
// In Hyprland, each monitor must display a distinct workspace ID, so
// logical workspace `k` (1..10) maps to physical workspace `i * 10 + k`
// on monitor `i` (sorted by monitor id: monitor 0 -> 1..10, monitor 1 ->
// 11..20, monitor 2 -> 21..30, ...). Both bar clicks and keyboard
// workspace switches (`Super + 1..0`, etc.) synchronize all monitors to
// the same logical workspace `k`.
Singleton {
    id: root

    readonly property bool combineScreens: SettingsService.flag("workspaces.combineScreens")
    readonly property bool usingLua: Hyprland.usingLua !== false

    property bool _syncing: false
    property int currentLogicalWorkspace: 1

    Timer {
        id: unlockSyncTimer
        interval: 260
        repeat: false
        onTriggered: root._syncing = false
    }

    function sortedMonitors() {
        const list = Hyprland.monitors?.values ? Array.from(Hyprland.monitors.values) : []
        return list.slice().sort((a, b) => (a.id ?? 0) - (b.id ?? 0))
    }

    function monitorIndex(monOrNameOrId) {
        if (monOrNameOrId === null || monOrNameOrId === undefined)
            return 0
        const mons = root.sortedMonitors()
        if (mons.length <= 1)
            return 0
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i]
            if (m === monOrNameOrId)
                return i
            if (typeof monOrNameOrId === "string" && m.name === monOrNameOrId)
                return i
            if (typeof monOrNameOrId === "number" && m.id === monOrNameOrId)
                return i
            if (typeof monOrNameOrId === "object") {
                if (monOrNameOrId.name && m.name === monOrNameOrId.name)
                    return i
                if (monOrNameOrId.id !== undefined && m.id === monOrNameOrId.id)
                    return i
            }
        }
        return 0
    }

    function logicalId(rawId) {
        const id = Number(rawId)
        if (!Number.isFinite(id) || id <= 0)
            return rawId
        if (!root.combineScreens)
            return id
        return ((id - 1) % 10) + 1
    }

    function physicalIdFor(monOrNameOrId, logicalWs) {
        const ws = Math.max(1, Math.round(Number(logicalWs) || 1))
        if (!root.combineScreens)
            return ws
        const idx = root.monitorIndex(monOrNameOrId)
        const k = ((ws - 1) % 10) + 1
        return idx * 10 + k
    }

    function activeWorkspaceFor(monitor) {
        const raw = monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1
        return root.logicalId(raw)
    }

    function occupiedWorkspaces() {
        const values = Hyprland.workspaces?.values ? Array.from(Hyprland.workspaces.values) : []
        const ids = values
            .filter(w => w.id > 0 && w.toplevels && w.toplevels.values && w.toplevels.values.length > 0)
            .map(w => root.logicalId(w.id))
        return Array.from(new Set(ids))
    }

    function syncAllToLogical(logicalWs, keepFocusedMonitorName) {
        const k = ((Math.max(1, Math.round(Number(logicalWs) || 1)) - 1) % 10) + 1
        root.currentLogicalWorkspace = k

        if (NiriWorkspaces.running) {
            for (const s of Quickshell.screens) {
                if (s && s.name)
                    NiriWorkspaces.focus(s.name, k)
            }
            if (keepFocusedMonitorName)
                NiriWorkspaces.focus(keepFocusedMonitorName, k)
            return
        }

        const mons = root.sortedMonitors()
        if (mons.length === 0)
            return

        if (mons.length === 1) {
            if ((mons[0].activeWorkspace?.id ?? -1) !== k) {
                root._syncing = true
                unlockSyncTimer.restart()
                Hyprland.dispatch(root.usingLua
                    ? "hl.dsp.focus({ workspace = " + k + " })"
                    : "workspace " + k)
            }
            return
        }

        let needsSync = false
        for (let i = 0; i < mons.length; i++) {
            const targetPhys = i * 10 + k
            if ((mons[i].activeWorkspace?.id ?? -1) !== targetPhys) {
                needsSync = true
                break
            }
        }
        if (!needsSync)
            return

        const focusTarget = keepFocusedMonitorName
            || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            || mons[0].name

        root._syncing = true
        unlockSyncTimer.restart()

        const cmds = []
        // Switch secondary monitors first (highest index down to 1) so if a
        // secondary monitor temporarily held workspace `k` (1..10) after a
        // keybind press, it vacates `k` before monitor 0 claims it.
        for (let i = mons.length - 1; i >= 0; i--) {
            const m = mons[i]
            if (!m || !m.name)
                continue
            const phys = i * 10 + k
            cmds.push("dispatch focusmonitor " + m.name)
            cmds.push("dispatch workspace " + phys)
            cmds.push("dispatch moveworkspacetomonitor " + phys + " " + m.name)
        }
        if (focusTarget)
            cmds.push("dispatch focusmonitor " + focusTarget)

        Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
    }

    function requestWorkspace(screen, monitor, workspace) {
        const ws = Math.max(1, Math.round(Number(workspace) || 1))
        const monName = monitor?.name || screen?.name || ""

        if (NiriWorkspaces.running) {
            if (root.combineScreens) {
                root.syncAllToLogical(ws, monName)
            } else if (screen?.name) {
                NiriWorkspaces.focus(screen.name, ws)
            }
            return
        }

        if (root.combineScreens) {
            root.syncAllToLogical(ws, monName)
            return
        }

        if (monitor && !monitor.focused && monitor.name) {
            Quickshell.execDetached([
                "hyprctl",
                "--batch",
                "dispatch focusmonitor " + monitor.name + " ; dispatch workspace " + ws
            ])
            return
        }

        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ workspace = " + ws + " })"
            : "workspace " + ws)
    }

    onCombineScreensChanged: {
        if (root.combineScreens) {
            const activeRaw = Hyprland.focusedWorkspace?.id ?? 1
            root.syncAllToLogical(root.logicalId(activeRaw), Hyprland.focusedMonitor?.name ?? "")
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!root.combineScreens || root._syncing)
                return
            if (event.name !== "workspace" && event.name !== "workspacev2")
                return
            const firstPart = String(event.data ?? "").split(",")[0].trim()
            const rawId = parseInt(firstPart, 10)
            if (!Number.isFinite(rawId) || rawId <= 0)
                return
            const k = root.logicalId(rawId)
            root.syncAllToLogical(k, Hyprland.focusedMonitor?.name ?? "")
        }
    }
}
