pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    property FileView themeFile: FileView {
        path: Quickshell.shellDir + "/Theme.json"
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var themeData: {
        const content = themeFile.text();
        return content.length > 0 ? JSON.parse(content) : ({});
    }

    readonly property color bg: themeData.bg || "#0B1B26"
    readonly property color bgSecondary: themeData.bgSecondary || "#151820"
    readonly property color bgElevated: themeData.bgElevated || "#252B38"
    readonly property color fg: themeData.fg || "#F2E8D5"
    readonly property color fgMuted: themeData.fgMuted || "#7F9AAE"
    readonly property color accent: themeData.accent || "#89B4FA"
    readonly property color accentHover: themeData.accentHover || "#A6C8FF"
    readonly property color border: themeData.border || "#343C4D"
    readonly property color success: themeData.success || "#A6E3A1"
    readonly property color warning: themeData.warning || "#F9E2AF"
    readonly property color error: themeData.error || "#C97B7B"
    readonly property string wallpaper: themeData.wallpaper || ""
}
