pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Which keyboard layout is active ("us", "ru", ...), read from Hyprland. State only,
// no window: the bar's layout pill (Bar.qml) and both lockscreen looks (LockSurface.qml,
// LockCalendar.qml) read it, so they always agree and Hyprland is asked once, not once
// per bar.
//
//   import qs.services
//   ...
//   text: KeyboardLayoutService.code      // "EN", or "" when there is nothing to switch between
//
// Only worth showing when more than one layout is configured: on a one-layout system a
// pill would permanently say "EN". So `code` is empty then, and every pill hides itself.
Singleton {
    id: root

    // Hyprland's name for the active keymap, "English (US)", "Russian", ...
    property string layoutName: ""
    // How many layouts kb_layout lists ("us,ru" is two).
    property int layoutCount: 0

    // Which of them is on, as its place in the list ("us,ru": us is 0).
    property int activeIndex: 0
    // kb_layout as the codes it lists, in order.
    property var layoutIds: []

    // The layouts people reach for, by their xkb code, in the order the Hyprland page lists
    // them. Names for the rows of a layout list; a code that is not here (a layout of your
    // own) is shown as the code. Not the keymap name Hyprland gives: it only names the
    // active one, so a row would change its writing as you pick.
    readonly property var commonLayouts: [
        { id: "us", label: "English (US)" }, { id: "gb", label: "English (UK)" },
        { id: "dk", label: "Danish" }, { id: "se", label: "Swedish" },
        { id: "no", label: "Norwegian" }, { id: "fi", label: "Finnish" },
        { id: "de", label: "German" }, { id: "fr", label: "French" },
        { id: "es", label: "Spanish" }, { id: "it", label: "Italian" },
        { id: "pt", label: "Portuguese" }, { id: "br", label: "Brazilian" },
        { id: "nl", label: "Dutch" }, { id: "pl", label: "Polish" },
        { id: "cz", label: "Czech" }, { id: "ph", label: "Filipino" },
        { id: "ru", label: "Russian" }, { id: "ua", label: "Ukrainian" },
        { id: "tr", label: "Turkish" }, { id: "jp", label: "Japanese" },
        { id: "kr", label: "Korean" }, { id: "ara", label: "Arabic" }
    ]

    // Configured layouts from HyprlandSettings ("us" by default), and helpers to manage
    // primary + second language from Settings > Bar or Settings > Hyprland.
    readonly property var configuredLayouts: HyprlandSettings.str("input.kb_layout", "us")
        .split(",").map(c => c.trim()).filter(c => c.length > 0)
    readonly property string primaryLayout: root.configuredLayouts.length > 0 ? root.configuredLayouts[0] : "us"
    readonly property string secondLayout: root.configuredLayouts.length > 1 ? root.configuredLayouts[1] : ""

    function setConfiguredLayouts(list) {
        if (!list || list.length === 0)
            return
        if (HyprlandSettings.str("input.kb_variant") !== "")
            HyprlandSettings.set("input.kb_variant", "str", "")
        HyprlandSettings.set("input.kb_layout", "str", list.join(","))
    }

    function setPrimaryLayout(id) {
        if (!id)
            return
        const rest = root.configuredLayouts.slice(1).filter(c => c !== id)
        root.setConfiguredLayouts([id].concat(rest))
    }

    function setSecondLayout(id) {
        const first = root.primaryLayout || "us"
        if (!id || id === "" || id === first) {
            root.setConfiguredLayouts([first])
            return
        }
        const extra = root.configuredLayouts.slice(2).filter(c => c !== first && c !== id)
        root.setConfiguredLayouts([first, id].concat(extra))
    }

    // What a list of layouts shows: [{ index, id, label }].
    readonly property var layouts: root.layoutIds.map((id, i) => {
        const known = root.commonLayouts.find(c => c.id === id)
        return {
            index: i,
            id: id,
            label: known ? known.label : id
        }
    })

    readonly property string code: root.layoutName !== ""
        ? root.layoutName.slice(0, 2).toUpperCase() : "EN"

    // `hyprctl switchxkblayout` is its own hyprctl command, not a dispatcher, so it is the
    // same on a Lua-mode and a hyprlang config. "all" moves every keyboard together, so the
    // code shown is always the one you are typing with.
    function cycle() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
        refetch.restart()
    }

    // Straight to one layout, on every keyboard.
    function select(index) {
        root.activeIndex = index
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)])
        refetch.restart()
    }

    // Ask again. A read already under way is let finish and then run once more, not killed:
    // a killed read ends with nothing in it, and an event, a reload and a lock can arrive
    // within the same moment.
    property bool again: false
    function refresh() {
        if (fetch.running)
            root.again = true
        else
            fetch.running = true
    }

    // A read can still fail (a shell reloading under it, no Hyprland at all), and nothing
    // else would ask again until Hyprland sent an event. So a failed read is tried again a
    // few times, not for ever: with no Hyprland (niri) it never works.
    property int failures: 0

    Process {
        id: fetch
        running: true
        command: ["hyprctl", "-j", "devices"]
        onExited: {
            if (root.again) {
                root.again = false
                fetch.running = true
            }
        }
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(collector.text)
                    const kb = (parsed.keyboards || []).find(k => k.main === true) || (parsed.keyboards || [])[0]
                    if (kb) {
                        root.layoutName = kb.active_keymap || ""
                        const ids = (kb.layout || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
                        root.layoutIds = ids
                        root.layoutCount = ids.length
                        root.activeIndex = kb.active_layout_index || 0
                    }
                    root.failures = 0
                } catch (e) {
                    // A reload in the middle of a read ends it with nothing in it, which is
                    // not worth a line each time: only the last try says so.
                    if (++root.failures < 4)
                        refetch.restart()
                    else
                        console.warn("KeyboardLayoutService: couldn't parse `hyprctl -j devices` for keyboard layout: " + e + " (got " + collector.text.length + " bytes)")
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Hyprland sends "activelayout" as "<device>,<layout name>"
            if (event.name === "activelayout") {
                root.layoutName = event.data.substring(event.data.indexOf(",") + 1)
                // The event gives the name, not the place in the list.
                root.refresh()
            }
            // A reload can add or drop layouts (kb_layout = "us,ru"), so ask again.
            else if (event.name === "configreloaded")
                root.refresh()
        }
    }

    // The Hyprland page's keyboard card changes kb_layout live: read the list again
    // a moment after, once Hyprland has rebuilt the keymaps.
    Connections {
        target: HyprlandSettings
        function onApplied(path) {
            if (path.indexOf("input.kb_") === 0)
                refetch.restart()
        }
    }

    // Locking is when the code matters most and when a missed event would hurt: nobody can
    // fix it from the lockscreen, so start from what Hyprland says right now.
    Connections {
        target: LockState
        function onLockedChanged() {
            if (LockState.locked)
                root.refresh()
        }
    }

    Timer {
        id: refetch
        interval: root.failures > 0 ? 2000 : 400
        onTriggered: root.refresh()
    }
}
