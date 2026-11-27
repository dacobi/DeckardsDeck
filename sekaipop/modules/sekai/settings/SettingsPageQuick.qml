import QtQuick
import Quickshell
import qs.services

// Quick: the things you reach for most, so they're a tap away instead of a
// page deep. Everything here is also somewhere else (the Quick Panel's
// tiles, the bar's buttons, the General / Bar / Desktop pages); it's the
// same state, so changing it here shows up there at once.
SettingsPage {
    id: page

    readonly property var src: host ? host.source : null
    // The monitor the phone is on: with one theme per monitor, Colours picks for it
    // (ThemeService.pickTheme; the main monitor's is the shell's theme).
    readonly property string screenName: QsWindow.window && QsWindow.window.screen ? String(QsWindow.window.screen.name) : ""

    SectionCard {
        title: "Look"

        SettingChoice {
            label: "Style"
            sublabel: "Edgy cyberdeck geometry or classic curvy SekaiPop"
            current: SettingsService.get("appearance.style")
            options: [
                { id: "cyberpunk", label: "Cyberpunk", icon: "terminal" },
                { id: "sekaipop", label: "SekaiPop", icon: "auto_awesome" }
            ]
            onPicked: id => SettingsService.set("appearance.style", id)
        }

        SettingChoice {
            label: "Mode"
            sublabel: "Light, dark, or near-black"
            current: ThemeService.mode
            options: [
                { id: "light", label: "Light", icon: "light_mode" },
                { id: "dark", label: "Dark", icon: "dark_mode" },
                { id: "darker", label: "Darker", icon: "bedtime" }
            ]
            onPicked: id => ThemeService.setModeAndSystem(id)
        }

        SettingChoice {
            label: "Colours"
            sublabel: "Whose colours the shell wears"
            current: ThemeService.themeFor(page.screenName)
            options: ThemeService.groups.map(g => ({
                id: g.id,
                label: g.name,
                swatch: [g.c.border, g.c.A, g.c.B]
            }))
            onPicked: id => ThemeService.pickTheme(page.screenName, id)
        }

        SettingAction {
            tileWidth: 310
            icon: "palette"
            label: "Palette tool"
            detail: "Colours from the wallpaper, music or luck. Nothing changes until you apply"
            onActivated: PaletteService.requestOpen()
        }
    }

    SectionCard {
        title: "Shell"

        SettingToggle {
            icon: page.src && page.src.notificationsOn ? "notifications_active" : "notifications_off"
            label: "Notifications"
            checked: page.src ? page.src.notificationsOn : true
            onToggled: if (page.src) page.src.toggleNotifications()
        }

        SettingToggle {
            icon: "nightlight"
            label: "Night Light"
            checked: page.src ? page.src.nightLightOn : false
            onToggled: if (page.src) page.src.toggleNightLight()
        }

        SettingToggle {
            icon: "coffee"
            label: "Keep Awake"
            checked: page.src ? page.src.keepAwakeOn : false
            onToggled: if (page.src) page.src.toggleKeepAwake()
        }

        SettingToggle {
            icon: "sports_esports"
            label: "Game Mode"
            checked: page.src ? page.src.gameModeOn : false
            onToggled: if (page.src) page.src.toggleGameMode()
        }

        SettingAction {
            icon: "wallpaper"
            label: "Wallpapers"
            detail: "Open the picker"
            onActivated: if (page.host) page.host.wallpapersRequested()
        }

        SettingStepper {
            icon: "aspect_ratio"
            label: "Shell size"
            from: 0.5
            to: 3
            step: 0.05
            decimals: 2
            suffix: "×"
            value: page.host ? ShellScale.effectiveFor(page.host.screenName) : 1
            onMoved: v => { if (page.host) ShellScale.setScale(page.host.screenName, v) }
        }

        SettingToggle {
            icon: "dock_to_bottom"
            label: "Dock"
            checked: SettingsService.flag("dock.visible")
            onToggled: SettingsService.toggle("dock.visible")
        }

        SettingToggle {
            icon: "visibility"
            label: "Bar"
            checked: SettingsService.flag("bar.visible")
            onToggled: SettingsService.toggle("bar.visible")
        }
    }

    SectionCard {
        title: "Bar"

        SettingChoice {
            label: "Style"
            current: BarStyleService.style
            options: [
                { id: "float", label: "Float", edge: "top", variant: "float" },
                { id: "straight", label: "Straight", edge: "top", variant: "straight" },
                { id: "transparent", label: "Transparent", edge: "top", variant: "transparent" },
                { id: "capsule", label: "Capsule", edge: "top", variant: "capsule" }
            ]
            onPicked: id => BarStyleService.setStyle(id)
        }

        SettingChoice {
            label: "Position"
            current: BarPositionService.position
            options: [
                { id: "top", label: "Top", edge: "top" },
                { id: "right", label: "Right", edge: "right" },
                { id: "bottom", label: "Bottom", edge: "bottom" },
                { id: "left", label: "Left", edge: "left" }
            ]
            onPicked: id => BarPositionService.setPosition(id)
        }
    }

    SectionCard {
        title: "Cyberdeck"

        SettingChoice {
            label: "Style"
            sublabel: "Follow the shell look, or pin the popup Cyberdeck to Cyberpunk or SekaiPop"
            current: {
                const s = SettingsService.get("quick.style")
                return (s === "cyberpunk" || s === "sekaipop") ? s : "auto"
            }
            options: [
                { id: "auto", label: "Auto", icon: "hdr_auto" },
                { id: "cyberpunk", label: "Cyberpunk", icon: "terminal" },
                { id: "sekaipop", label: "SekaiPop", icon: "auto_awesome" }
            ]
            onPicked: id => SettingsService.set("quick.style", id)
        }

        SettingChoice {
            label: "Pose"
            sublabel: "2.5D tilted deck chassis or 2D flat front-on view"
            current: SettingsService.flag("quick.flat") ? "flat" : "tilt"
            options: [
                { id: "flat", label: "2D Flat", icon: "crop_portrait" },
                { id: "tilt", label: "2.5D Deck", icon: "view_in_ar" }
            ]
            onPicked: id => SettingsService.set("quick.flat", id === "flat")
        }

        SettingChoice {
            label: "Phone wallpaper"
            sublabel: "Backdrop behind the Cyberdeck and Apps screen"
            current: PanelImages.phoneMode
            options: [
                { id: "off", label: "Off", icon: "hide_image" },
                { id: "desktop", label: "Desktop", icon: "wallpaper" },
                { id: "picture", label: "A picture", icon: "image" }
            ]
            onPicked: id => {
                if (id === "picture" && PanelImages.phonePath === "")
                    PanelImages.pick("phone")
                else
                    SettingsService.set("phone.wallpaper", id)
            }
        }

        SettingToggle {
            icon: "blur_on"
            label: "Phone shadow"
            detail: SettingsService.flag("quick.phoneShadow") ? "ON" : "OFF"
            checked: SettingsService.flag("quick.phoneShadow")
            onToggled: SettingsService.toggle("quick.phoneShadow")
        }

        SettingToggle {
            icon: "swipe_up"
            label: "Hot edge"
            detail: SettingsService.flag("panel.hotEdge") ? "Bottom centre" : "OFF"
            checked: SettingsService.flag("panel.hotEdge")
            onToggled: SettingsService.toggle("panel.hotEdge")
        }

        SettingToggle {
            icon: "ads_click"
            label: "Peek first"
            detail: SettingsService.flag("panel.hotPeek") ? "Tip first" : "Full open"
            checked: SettingsService.flag("panel.hotPeek")
            onToggled: SettingsService.toggle("panel.hotPeek")
        }
    }

    SectionCard {
        title: "Settings Panel"

        SettingChoice {
            label: "Style"
            sublabel: "Follow the shell look, or pin the rotate-out Settings panel to Cyberpunk or SekaiPop"
            current: {
                const s = SettingsService.get("settings.style")
                return (s === "cyberpunk" || s === "sekaipop") ? s : "auto"
            }
            options: [
                { id: "auto", label: "Auto", icon: "hdr_auto" },
                { id: "cyberpunk", label: "Cyberpunk", icon: "terminal" },
                { id: "sekaipop", label: "SekaiPop", icon: "auto_awesome" }
            ]
            onPicked: id => SettingsService.set("settings.style", id)
        }

        SettingChoice {
            label: "Pose"
            sublabel: "2.5D tilted landscape deck chassis or 2D flat front-on view"
            current: SettingsService.flag("settings.flat") ? "flat" : "tilt"
            options: [
                { id: "flat", label: "2D Flat", icon: "crop_landscape" },
                { id: "tilt", label: "2.5D Deck", icon: "view_in_ar" }
            ]
            onPicked: id => SettingsService.set("settings.flat", id === "flat")
        }
    }

    SectionCard {
        title: "Desktop widgets"

        SettingToggle {
            icon: "schedule"
            label: "Clock"
            checked: ClockService.shown
            onToggled: ClockService.setShown(!ClockService.shown)
        }

        SettingToggle {
            icon: "person"
            label: "User card"
            checked: UserCardService.shown
            onToggled: UserCardService.setShown(!UserCardService.shown)
        }

        SettingToggle {
            icon: "partly_cloudy_day"
            label: "Weather card"
            checked: WeatherCardService.shown
            onToggled: WeatherCardService.setShown(!WeatherCardService.shown)
        }

        SettingToggle {
            icon: "calendar_month"
            label: "Calendar card"
            checked: CalendarCardService.shown
            onToggled: CalendarCardService.setShown(!CalendarCardService.shown)
        }

        SettingToggle {
            icon: "palette"
            label: "Palette card"
            checked: PaletteService.shown
            onToggled: PaletteService.setShown(!PaletteService.shown)
        }

        SettingToggle {
            icon: "lyrics"
            label: "Lyrics"
            detail: "The words of the song that is playing, on the desktop"
            checked: LyricsService.shown
            onToggled: LyricsService.setShown(!LyricsService.shown)
        }

        SettingToggle {
            icon: "task_alt"
            label: "To-Do"
            checked: TodoService.shown
            onToggled: TodoService.setShown(!TodoService.shown)
        }

        SettingToggle {
            icon: "sticky_note_2"
            label: "Sticky notes"
            checked: NotesService.active
            onToggled: NotesService.setShown(!NotesService.active)
        }

        SettingToggle {
            icon: EditMode.widgetsLocked ? "lock" : "lock_open"
            label: "Lock widgets"
            checked: EditMode.widgetsLocked
            onToggled: EditMode.toggleWidgetsLocked()
        }
    }
}
