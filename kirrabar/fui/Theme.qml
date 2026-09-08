pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property color bg: "#070707"
    readonly property color bgRaised: "#121212"
    readonly property color bgPanel: "#0c0c0c"
    readonly property color ink: "#0a0a0a"

    readonly property color line: "#e6e6e6"
    readonly property color lineDim: "#5a5a5a"
    readonly property color lineFaint: "#2a2a2a"

    readonly property color text: "#f3f3f3"
    readonly property color textDim: "#8a8a8a"
    readonly property color textMute: "#4a4a4a"
    readonly property color warn: "#ff7a18"
    readonly property color callLive: "#3ee06a"
    readonly property color callDead: "#e0182a"
    readonly property color callEdge: "#2bb85a"
    readonly property color callEdgeDead: "#ff3344"

    readonly property string fontHud: "Fira Sans"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    readonly property int barHeight: 58
    readonly property int chamfer: 20
    readonly property int contentPad: 32

    readonly property int lockFormMs: 200
    readonly property int lockLineMs: 200
    readonly property int menuWaitMs: 200
    readonly property int menuGrowMs: 160
    readonly property real pickZoom: 1.16
    readonly property int zoomMs: 180
    readonly property int ringSpinOutMs: 5600
    readonly property int ringSpinInMs: 3800

    function lockInner(w: real, h: real, pad: real): real {
        return Math.hypot(w, h) * 0.5 + pad
    }

    function lockR(w: real, h: real, pad: real): real {
        return Math.ceil((Math.hypot(w, h) * 0.5 + pad) / 0.74)
    }
}
