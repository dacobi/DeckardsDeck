// Unit tests for the "Launcher" bar/dock hybrid widget (LauncherBarService.qml,
// AppDragService.qml, LauncherBar.qml, and shell/settings/preset wiring).
"use strict";
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const top = path.join(__dirname, "..", "..");
const read = rel => fs.readFileSync(path.join(top, rel), "utf8");

let n = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); n++; };

const svcSrc = read("services/LauncherBarService.qml");
const dragSrc = read("services/AppDragService.qml");
const barSrc = read("modules/sekai/launcherBar/LauncherBar.qml");
const ghostSrc = read("modules/sekai/launcherBar/AppDragGhost.qml");
const faceSrc = read("modules/sekai/launcher/LauncherFace.qml");
const rowSrc = read("modules/sekai/launcher/AppResultRow.qml");
const settingsSrc = read("services/SettingsService.qml");
const pageSrc = read("modules/sekai/settings/SettingsPageDesktop.qml");
const shellSrc = read("shell.qml");
const editSrc = read("services/EditMode.qml");
const presetSrc = read("services/PresetWidgets.qml");

// 1. LauncherBarService methods & state
ok(/^pragma Singleton/.test(svcSrc), "LauncherBarService is a singleton");
for (const fn of ["setShown", "setPosition", "addApp", "removeAt", "removeApp", "move", "clear", "launch", "addDrop", "snapshot", "restore", "persist"]) {
    ok(new RegExp("function\\s+" + fn + "\\s*\\(").test(svcSrc), "LauncherBarService defines " + fn + "()");
}

// 2. AppDragService methods & state
ok(/^pragma Singleton/.test(dragSrc), "AppDragService is a singleton");
for (const fn of ["registerTarget", "unregisterTarget", "toScreenPoint", "startDrag", "updateDrag", "endDrag", "cancelDrag"]) {
    ok(new RegExp("function\\s+" + fn + "\\s*\\(").test(dragSrc), "AppDragService defines " + fn + "()");
}

// 3. LauncherBar UI features (drag reorder, drag off to remove, DropArea, AppDragService target)
ok(/AppDragService\.registerTarget\(launcherWin\)/.test(barSrc), "LauncherBar registers with AppDragService");
ok(/function testAppDrag\(screenX, screenY\)/.test(barSrc), "LauncherBar implements testAppDrag");
ok(/DropArea \{/.test(barSrc) && /LauncherBarService\.addDrop\(drop, idx\)/.test(barSrc), "LauncherBar accepts external DropArea drops");
ok(/LauncherBarService\.removeAt\(from\)/.test(barSrc) && /LauncherBarService\.move\(from, to\)/.test(barSrc), "LauncherBar supports drag-off-to-remove and drag-to-reorder");
ok(/LauncherBarService\.launch\(keySlot\.modelData\)/.test(barSrc), "LauncherBar launches app on click");

// 4. LauncherFace & AppResultRow initiate AppDragService drags
ok(/AppDragService\.startDrag\(/.test(faceSrc) && /AppDragService\.endDrag\(\)/.test(faceSrc), "LauncherFace grid tiles support dragging to Launcher");
ok(/AppDragService\.startDrag\(/.test(rowSrc) && /AppDragService\.endDrag\(\)/.test(rowSrc), "AppResultRow search rows support dragging to Launcher");

// 5. Settings, EditMode, PresetWidgets, and shell.qml wiring
for (const key of ["launcherbar.perMonitor", "launcherbar.screen", "launcherbar.position", "launcherbar.style", "launcherbar.hideMode", "launcherbar.iconSize", "launcherbar.addButton"]) {
    ok(settingsSrc.includes('"' + key + '":'), "SettingsService defines default for " + key);
}
ok(/title: "Launcher"/.test(pageSrc), "SettingsPageDesktop has Launcher section card");
ok(/\{ id: "launcherbar", title: "Launcher", icon: "apps" \}/.test(editSrc), "EditMode.widgetList includes Launcher");
ok(/\{ id: "launcherbar", service: LauncherBarService, skip: \["apps"\] \}/.test(presetSrc), "PresetWidgets includes launcherbar with skip: ['apps']");
ok(/target: "launcherbar"/.test(shellSrc) && /LauncherBar \{/.test(shellSrc) && /AppDragGhost \{\}/.test(shellSrc), "shell.qml instantiates LauncherBar, AppDragGhost, and launcherbar IpcHandler");
ok(/WlrLayershell\.namespace: "sekaipop-app-drag-ghost"/.test(ghostSrc), "AppDragGhost uses overlay layer namespace");

console.log("launcherbar_unit: all " + n + " checks passed");
