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
    property bool _wasCombined: false
    property int currentLogicalWorkspace: 1
    property string lastFocusedMonitorName: ""

    Timer {
        id: unlockSyncTimer
        interval: 280
        repeat: false
        onTriggered: root._syncing = false
    }

    function dispatch(lua, classic) {
        Hyprland.dispatch(root.usingLua ? lua : classic)
    }

    function addrKey(t) {
        const a = t ? String(t.address ?? "") : ""
        if (a === "")
            return ""
        return a.startsWith("0x") ? a : "0x" + a
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
        if (root.combineScreens)
            return root.currentLogicalWorkspace
        return root.logicalId(raw)
    }

    function occupiedWorkspaces() {
        const values = Hyprland.workspaces?.values ? Array.from(Hyprland.workspaces.values) : []
        const ids = values
            .filter(w => w.id > 0 && w.toplevels && w.toplevels.values && w.toplevels.values.length > 0)
            .map(w => root.logicalId(w.id))
        return Array.from(new Set(ids))
    }

    function syncAllToLogical(logicalWs, keepFocusedMonitorName, migrateSecondaryWindows) {
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
                root.dispatch(
                    "hl.dsp.focus({ workspace = " + k + " })",
                    "workspace " + k
                )
            }
            return
        }

        if (migrateSecondaryWindows === true) {
            const tls = Hyprland.toplevels?.values ?? []
            for (let i = 1; i < mons.length; i++) {
                const curWs = mons[i].activeWorkspace?.id ?? -1
                const targetPhys = i * 10 + k
                if (curWs > 0 && curWs !== targetPhys) {
                    for (let j = 0; j < tls.length; j++) {
                        const t = tls[j]
                        if (!t || !t.workspace || t.workspace.id !== curWs)
                            continue
                        const addr = root.addrKey(t)
                        if (addr !== "") {
                            root.dispatch(
                                "hl.dsp.window.move({ workspace = " + targetPhys + ", follow = false, window = \"address:" + addr + "\" })",
                                "movetoworkspacesilent " + targetPhys + ",address:" + addr
                            )
                        }
                    }
                }
            }
        }

        let needsSync = migrateSecondaryWindows === true
        if (!needsSync) {
            for (let i = 0; i < mons.length; i++) {
                const targetPhys = i * 10 + k
                if ((mons[i].activeWorkspace?.id ?? -1) !== targetPhys) {
                    needsSync = true
                    break
                }
            }
        }
        if (!needsSync)
            return

        const focusTarget = keepFocusedMonitorName
            || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            || root.lastFocusedMonitorName
            || mons[0].name

        root._syncing = true
        unlockSyncTimer.restart()

        // Switch secondary monitors first (highest index down to 0) so if a
        // secondary monitor temporarily held workspace `k` (1..10) after a
        // keybind press, it vacates `k` before monitor 0 claims it.
        for (let i = mons.length - 1; i >= 0; i--) {
            const m = mons[i]
            if (!m || !m.name)
                continue
            const phys = i * 10 + k
            root.dispatch("hl.dsp.focus({ monitor = \"" + m.name + "\" })", "focusmonitor " + m.name)
            root.dispatch("hl.dsp.workspace.move({ workspace = " + phys + ", monitor = \"" + m.name + "\" })", "moveworkspacetomonitor " + phys + " " + m.name)
            root.dispatch("hl.dsp.focus({ monitor = \"" + m.name + "\" })", "focusmonitor " + m.name)
            root.dispatch("hl.dsp.focus({ workspace = " + phys + " })", "workspace " + phys)
        }
        if (focusTarget)
            root.dispatch("hl.dsp.focus({ monitor = \"" + focusTarget + "\" })", "focusmonitor " + focusTarget)
    }

    function separateScreens() {
        if (NiriWorkspaces.running)
            return
        const mons = root.sortedMonitors()
        if (mons.length <= 1)
            return

        const focusTarget = (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            || root.lastFocusedMonitorName
            || mons[0].name

        const used = new Set([mons[0].activeWorkspace?.id ?? 1])
        const tls = Hyprland.toplevels?.values ?? []

        root._syncing = true
        unlockSyncTimer.restart()

        for (let i = 1; i < mons.length; i++) {
            const m = mons[i]
            if (!m || !m.name)
                continue
            let targetWs = i + 1
            while (used.has(targetWs) && targetWs <= 10)
                targetWs++
            used.add(targetWs)

            const curWs = m.activeWorkspace?.id ?? -1
            for (let j = 0; j < tls.length; j++) {
                const t = tls[j]
                if (!t || !t.workspace)
                    continue
                const wId = t.workspace.id
                if (wId <= 10)
                    continue
                const sliceIdx = Math.floor((wId - 1) / 10)
                if (sliceIdx !== i)
                    continue
                const destWs = (wId === curWs) ? targetWs : (((wId - 1) % 10) + 1)
                const addr = root.addrKey(t)
                if (addr !== "") {
                    root.dispatch(
                        "hl.dsp.window.move({ workspace = " + destWs + ", follow = false, window = \"address:" + addr + "\" })",
                        "movetoworkspacesilent " + destWs + ",address:" + addr
                    )
                }
            }

            if (curWs > 10) {
                root.dispatch("hl.dsp.focus({ monitor = \"" + m.name + "\" })", "focusmonitor " + m.name)
                root.dispatch("hl.dsp.workspace.move({ workspace = " + targetWs + ", monitor = \"" + m.name + "\" })", "moveworkspacetomonitor " + targetWs + " " + m.name)
                root.dispatch("hl.dsp.focus({ monitor = \"" + m.name + "\" })", "focusmonitor " + m.name)
                root.dispatch("hl.dsp.focus({ workspace = " + targetWs + " })", "workspace " + targetWs)
            }
        }

        if (focusTarget)
            root.dispatch("hl.dsp.focus({ monitor = \"" + focusTarget + "\" })", "focusmonitor " + focusTarget)
    }

    function requestWorkspace(screen, monitor, workspace) {
        const ws = Math.max(1, Math.round(Number(workspace) || 1))
        const monName = monitor?.name || screen?.name || ""

        if (NiriWorkspaces.running) {
            if (root.combineScreens) {
                root.syncAllToLogical(ws, monName, false)
            } else if (screen?.name) {
                NiriWorkspaces.focus(screen.name, ws)
            }
            return
        }

        if (root.combineScreens) {
            root.syncAllToLogical(ws, monName, false)
            return
        }

        if (monitor && !monitor.focused && monitor.name) {
            root.dispatch("hl.dsp.focus({ monitor = \"" + monitor.name + "\" })", "focusmonitor " + monitor.name)
            root.dispatch("hl.dsp.focus({ workspace = " + ws + " })", "workspace " + ws)
            return
        }

        root.dispatch(
            "hl.dsp.focus({ workspace = " + ws + " })",
            "workspace " + ws
        )
    }

    onCombineScreensChanged: {
        if (root.combineScreens) {
            root._wasCombined = true
            const activeRaw = Hyprland.focusedWorkspace?.id ?? 1
            const k = ((Math.max(1, activeRaw) - 1) % 10) + 1
            root.syncAllToLogical(k, Hyprland.focusedMonitor?.name ?? "", true)
        } else if (root._wasCombined) {
            root._wasCombined = false
            root.separateScreens()
        }
    }

    Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
            if (root.combineScreens && !root._syncing) {
                const activeRaw = Hyprland.focusedWorkspace?.id ?? root.currentLogicalWorkspace
                const k = ((Math.max(1, activeRaw) - 1) % 10) + 1
                root.syncAllToLogical(k, Hyprland.focusedMonitor?.name ?? "", false)
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "focusedmon" || event.name === "focusedmonv2") {
                const monName = String(event.data ?? "").split(",")[0].trim()
                if (monName !== "")
                    root.lastFocusedMonitorName = monName
                return
            }
            if (!root.combineScreens || root._syncing)
                return
            if (event.name !== "workspace" && event.name !== "workspacev2")
                return
            const firstPart = String(event.data ?? "").split(",")[0].trim()
            const rawId = parseInt(firstPart, 10)
            if (!Number.isFinite(rawId) || rawId <= 0)
                return
            const k = root.logicalId(rawId)
            root.syncAllToLogical(k, Hyprland.focusedMonitor?.name ?? root.lastFocusedMonitorName, false)
        }
    }

    IpcHandler {
        target: "workspaces"

        function focus(ws: string): void {
            const n = parseInt(ws, 10)
            if (!Number.isFinite(n) || n <= 0)
                return
            if (root.combineScreens) {
                root.syncAllToLogical(n, Hyprland.focusedMonitor?.name ?? "", false)
            } else {
                root.dispatch("hl.dsp.focus({ workspace = " + n + " })", "workspace " + n)
            }
        }
    }
}
