pragma ComponentBehavior: Bound

import QtQuick
import "svc"

Item {
    id: map

    property var screen: null
    property bool paused: false
    property real boot: 0
    property bool primed: false

    readonly property real pad: 10
    readonly property real padY: 46
    readonly property real dock: 204
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real viewW: {
        const p = map.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real viewH: {
        const p = map.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real moduleW: {
        const usable = map.viewW - map.pad * 2
        const raw = (usable - map.clusterGap * 2) / 3
        const minW = map.framePad * 2 + map.dock + 20 + 96
        return Math.max(minW, raw)
    }
    readonly property real stackPitch: map.dock + map.framePad * 2 + map.clusterGap
    readonly property real frameX: map.pad + map.moduleW + map.clusterGap
    readonly property real frameY: map.viewH - map.dock - map.padY - 3 * map.stackPitch - map.framePad
    readonly property real frameW: map.moduleW * 2 + map.clusterGap
    readonly property real frameH: {
        const ctrlY = map.viewH - map.dock - map.padY - map.framePad
        return Math.max(120, ctrlY - map.clusterGap - map.frameY)
    }

    x: 0
    y: 0
    width: map.viewW
    height: map.viewH
    opacity: map.paused ? 0 : 1
    visible: opacity > 0.02

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function play(): void {
        if (map.primed)
            return
        map.primed = true
        map.boot = 0
        intro.start()
    }

    SequentialAnimation {
        id: intro
        PauseAnimation {
            duration: 80
        }
        NumberAnimation {
            target: map
            property: "boot"
            from: 0
            to: 1
            duration: 2000
            easing.type: Easing.Linear
        }
    }

    Component.onCompleted: {
        if (!map.paused)
            map.play()
    }

    onPausedChanged: {
        if (!map.paused)
            map.play()
    }

    HoloSpace {
        x: map.frameX
        y: map.frameY
        width: map.frameW
        height: map.frameH
        paused: map.paused
        boot: map.boot
    }

    HudFrame {
        visible: !map.paused
        opacity: visible ? Math.min(1, map.boot * 12) : 0
        pad: 0
        arm: 14
        thick: 1.15
        inset: 3.5
        x: map.frameX + 160
        y: map.frameY
        width: map.frameW - 320
        height: map.frameH

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }
}
