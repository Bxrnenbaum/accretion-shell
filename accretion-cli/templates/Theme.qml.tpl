pragma Singleton

import QtQuick

QtObject {
    // backgrounds
    readonly property color bg: "{{color.bg}}"
    readonly property color bgSecondary: "{{color.bgSecondary}}"
    readonly property color bgElevated: "{{color.bgElevated}}"

    // foreground
    readonly property color fg: "{{color.fg}}"
    readonly property color fgMuted: "{{color.fgMuted}}"

    // accent
    readonly property color accent: "{{color.accent}}"
    readonly property color accentHover: "{{color.accentHover}}"
    readonly property color border: "{{color.border}}"

    // status
    readonly property color success: "{{color.success}}"
    readonly property color warning: "{{color.warning}}"
    readonly property color error: "{{color.error}}"

}
