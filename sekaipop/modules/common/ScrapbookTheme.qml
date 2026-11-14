pragma Singleton
import QtQuick
import qs.services

// Palette for the paper-styled surfaces in the shell that aren't part
// of the navy/cyan/mint Virtual Singer look: the film-strip Overview
// (Overview.qml / FilmStrip.qml), the cork-board cheat sheet
// (CheatSheet.qml / CorkBoard.qml) and the wallpaper board
// (the wallpaper board, now WallpaperFace.qml, and the small pieces it's built from). Kept
// separate from Theme.qml on purpose — nothing here should leak into
// Theme.qml, and nothing in Theme.qml should leak in here.
//
// Auto-registered the same way Theme.qml is (a pragma Singleton file at
// the config's root) — every file just uses `ScrapbookTheme.foo`, no
// import needed.
QtObject {
    id: root

    // ===== paper (Terminal Data Slate) =====
    readonly property color page: "#0f141e"        // dark terminal slate
    readonly property color ink: "#d6eef8"         // phosphor cyan-white ink

    // ===== accents (Hazard / Telemetry Tape) =====
    readonly property color tapeTeal: "#00e5ff"
    readonly property color tapeCoral: "#ff6b1a"
    readonly property color tapeMint: "#00e676"
    readonly property color tag: "#ff9e2c"          // amber data tag
    readonly property color accentCurrent: "#00e5ff" // "this one's picked" ring + marker

    // ===== tactical evidence board (CorkBoard.qml) =====
    readonly property color cork: "#0f141e"
    readonly property color corkLight: "#182232"
    readonly property color corkDark: "#090c12"
    readonly property color corkSpeck: "#05070b"
    readonly property color frameWood: "#161e2c"
    readonly property color frameHighlight: "#26344a"
    readonly property color frameShade: "#070a0f"
    readonly property color noteShadow: "#04060a"   // pinned slate's drop shadow
    readonly property color pinPink: "#ff2a6d"

    // ===== Esper microfiche reel (the Overview) =====
    readonly property color filmBase: "#090c12"        // the data reel base
    readonly property color filmEdge: "#040609"        // its dark outline / gaps between frames
    readonly property color filmFrame: "#111722"       // one frame's slightly lighter box
    readonly property color filmScreen: "#161e2c"      // the picture area inside a frame
    readonly property color filmScreenHover: "#182c3c" // ...while a window is dragged over it
    readonly property color filmHole: "#1e293b"        // sprocket holes
    readonly property color filmHoleShade: "#0b0f17"   // their inner shadow
    readonly property color filmPrint: "#ff9e2c"       // amber edge print (frame numbers)
    readonly property color filmPrintSoft: "#8800e5ff" // faint telemetry text on the picture area

    // ===== wallpaper board =====
    readonly property color boardBg: ThemeService.palette.boardBg            // the tray behind the cards
    readonly property color boardBgClear: Qt.rgba(boardBg.r, boardBg.g, boardBg.b, 0)  // same colour, no alpha (edge fades)
    readonly property color boardDot: ThemeService.palette.boardDot           // the dot grid on it
    readonly property color tapePink: "#ff2a6d"           // 4th tape colour (others above)
    readonly property color accentPink: "#ff9e2c"         // same amber as Theme.irisColorPink
    readonly property color labelPaper: "#121824"         // name tags
    readonly property color inkSoft: "#7890a8"            // captions
}
