import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Keyboard language bar module: shows the active language code ("EN" by default)
// and cycles to the next configured language when clicked.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string layoutCode: "EN"

    // Which edge the bar is on, so the hover tag opens towards the screen.
    property string barPosition: "top"

    // What the hover tag says.
    readonly property string tipText: KeyboardLayoutService.configuredLayouts.length > 1
        ? "Keyboard language: " + (KeyboardLayoutService.layoutName || root.layoutCode.toUpperCase()) + " (click to switch)"
        : "Keyboard language: " + (KeyboardLayoutService.layoutName || root.layoutCode.toUpperCase()) + " (add a 2nd language in Settings > Bar)"

    signal clicked()

    visible: layoutCode !== ""
    implicitWidth: layoutCode !== "" ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        fillColor: mt.chipFill
        pressed: area.pressed
        implicitWidth: label.implicitWidth + (pill.capsule ? 20 : 28)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.layoutCode
            color: mt.chipInk
            font.family: mt.fontFamily
            font.pixelSize: mt.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // The hover tag (BarTip.qml): what the popup behind the click would tell you, at a glance.
    BarTip {
        shown: area.containsMouse
        pressed: area.pressed
        text: root.tipText
        barPosition: root.barPosition
    }
}
