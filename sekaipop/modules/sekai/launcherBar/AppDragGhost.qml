import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.launcher

// Click-through overlay window showing the application icon being dragged
// from the Cyberdeck Apps screen onto the Launcher bar.
PanelWindow {
    id: ghostWin

    readonly property var mt: Theme.of(screen)

    screen: Quickshell.screens.find(s => s.name === AppDragService.screenName) ?? Quickshell.screens[0]

    readonly property real uiScale: ShellScale.forScreen(ghostWin.screen)

    visible: AppDragService.active && AppDragService.app !== null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "sekaipop-app-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Completely click-through so pointer events reach the source and target windows.
    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    mask: Region {
        item: emptyMask
    }

    readonly property string iconPath: (AppDragService.app && AppDragService.app.icon)
        ? IconCursorService.path(AppDragService.app.icon, true) : ""
    readonly property bool noIcon: ghostWin.iconPath === "" || dragIcon.status === Image.Error

    Item {
        id: badge
        x: Math.round(AppDragService.cursorX - width / 2)
        y: Math.round(AppDragService.cursorY - height / 2)
        width: Math.round(64 * ghostWin.uiScale)
        height: Math.round(64 * ghostWin.uiScale)

        Pill {
            anchors.fill: parent
            cornerRadius: mt.edgy ? 6 : 16
            ringWidth: mt.edgy ? 2 : 5
            fillColor: mt.edgy ? mt.hudSurface : mt.surface
            ringColorTop: AppDragService.overLauncher ? mt.accentCyan : (mt.edgy ? mt.accentYellow : mt.accentMint)
            ringColorBottom: ringColorTop
            shadowDx: 0
            shadowDy: 4

            IconImage {
                id: dragIcon
                anchors.centerIn: parent
                width: Math.round(42 * ghostWin.uiScale)
                height: Math.round(42 * ghostWin.uiScale)
                implicitSize: Math.round(42 * ghostWin.uiScale)
                visible: !ghostWin.noIcon
                source: ghostWin.iconPath
            }

            Loader {
                active: ghostWin.noIcon
                anchors.centerIn: parent
                width: Math.round(42 * ghostWin.uiScale)
                height: Math.round(42 * ghostWin.uiScale)
                sourceComponent: AppPlaceholder {
                    size: Math.round(42 * ghostWin.uiScale)
                    name: AppDragService.app ? AppDragService.app.name : "App"
                }
            }
        }

        // "+ Launcher" indicator pill when hovering over the Launcher drop zone
        Rectangle {
            visible: AppDragService.overLauncher
            anchors.horizontalCenter: parent.horizontalCenter
            y: -Math.round(26 * ghostWin.uiScale)
            width: tagLabel.implicitWidth + 16
            height: Math.round(22 * ghostWin.uiScale)
            radius: mt.edgy ? 3 : 11
            color: mt.edgy ? mt.hudSurface : mt.accentMint
            border.width: 2
            border.color: mt.edgy ? mt.accentCyan : mt.line

            Text {
                id: tagLabel
                anchors.centerIn: parent
                text: "+ Launcher"
                color: mt.edgy ? mt.accentCyan : mt.colBorder
                font.family: mt.fontFamily
                font.pixelSize: Math.round(12 * ghostWin.uiScale)
                font.weight: Font.ExtraBold
            }
        }
    }
}
