pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property color bg: "#070707"
    readonly property color line: "#e6e6e6"
    readonly property color lineDim: "#5a5a5a"
    readonly property color lineFaint: "#2a2a2a"

    readonly property color text: "#f3f3f3"
    readonly property color textDim: "#8a8a8a"
    readonly property color textMute: "#4a4a4a"
    readonly property color warn: Accent.warn

    readonly property string fontHud: "Fira Sans"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
}
