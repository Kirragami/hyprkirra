pragma ComponentBehavior: Bound

import QtQuick
import "svc"

Item {
    id: bay

    property bool paused: false
    property bool compact: false
    property real appear: 0
    property real settle: 0

    readonly property int stackIndex: 0
    readonly property real pad: 10
    readonly property real padY: 46
    readonly property real dock: 204
    readonly property real textGap: 20
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real viewW: {
        const p = bay.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real moduleW: {
        const usable = bay.viewW - bay.pad * 2
        const gaps = bay.clusterGap * 2
        const raw = (usable - gaps) / 3
        const minW = bay.framePad * 2 + bay.dock + bay.textGap + 96
        return Math.max(minW, raw)
    }
    readonly property real plateW: Math.max(96, bay.moduleW - bay.framePad * 2 - bay.dock - bay.textGap)
    readonly property real stackPitch: bay.dock + bay.framePad * 2 + bay.clusterGap
    readonly property real viewH: {
        const p = bay.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real frameX: bay.pad + bay.moduleW + bay.clusterGap
    readonly property real frameY: bay.viewH - bay.dock - bay.padY - 3 * bay.stackPitch - bay.framePad
    readonly property real frameW: bay.moduleW * 2 + bay.clusterGap
    readonly property real frameH: {
        const ctrlY = bay.viewH - bay.dock - bay.padY - bay.framePad
        return Math.max(120, ctrlY - bay.clusterGap - bay.frameY)
    }
    readonly property real dockX: bay.pad + bay.framePad
    readonly property real dockY: {
        const p = bay.parent
        if (!p)
            return 0
        return p.height - bay.dock - bay.padY - bay.stackIndex * bay.stackPitch
    }
    readonly property real hero: bay.dock
    readonly property real spawnX: bay.frameX + bay.frameW * 0.5 - bay.hero * 0.5
    readonly property real spawnY: bay.frameY + bay.frameH * 0.34 - bay.hero * 0.5

    width: bay.compact ? bay.dock : bay.hero
    height: width
    transformOrigin: Item.TopLeft
    scale: {
        if (bay.compact)
            return 1
        const h = Math.max(1, bay.hero)
        return 1 + (bay.dock / h - 1) * bay.settle
    }
    x: {
        const p = bay.parent
        if (!p)
            return 0
        return bay.spawnX * (1 - bay.settle) + bay.dockX * bay.settle
    }
    y: {
        const p = bay.parent
        if (!p)
            return 0
        return bay.spawnY * (1 - bay.settle) + bay.dockY * bay.settle
    }

    Component.onCompleted: intro.start()

    GlitchReveal {
        id: fx
        anchors.fill: parent
        clip: false
        duration: 240
        intensity: 0.5
        slices: 5
        transformOrigin: Item.Center
        scale: 0.9 + 0.1 * bay.appear
        opacity: bay.paused ? 0 : (bay.appear > 0.01 ? Math.min(1, 0.35 + 0.65 * bay.appear) : 0)

        DiskCore {
            anchors.fill: parent
            live: bay.compact
            paused: bay.paused
        }
    }

    SequentialAnimation {
        id: intro
        PauseAnimation {
            duration: 60
        }
        ScriptAction {
            script: fx.play(240)
        }
        NumberAnimation {
            target: bay
            property: "appear"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 80
        }
        NumberAnimation {
            target: bay
            property: "settle"
            to: 1
            duration: 420
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1, 0.3, 1]
        }
        PauseAnimation {
            duration: 32
        }
        ScriptAction {
            script: bay.compact = true
        }
    }
}
