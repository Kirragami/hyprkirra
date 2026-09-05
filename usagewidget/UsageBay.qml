pragma ComponentBehavior: Bound

import QtQuick
import "svc"

Item {
    id: bay

    property bool paused: false
    property bool compact: false
    property real appear: 0
    property real settle: 0

    readonly property real pad: 22
    readonly property real dock: 236
    readonly property real geoDock: 236
    readonly property real geoGap: 16
    readonly property real geoPlate: 360
    readonly property real geoFrame: 10
    readonly property real bayFrame: 10
    readonly property real bayGap: 36
    readonly property real dockX: bay.pad + bay.geoDock + bay.geoGap + bay.geoPlate + bay.geoFrame + bay.bayGap + bay.bayFrame
    readonly property real hero: {
        const p = bay.parent
        if (!p)
            return 480
        return Math.min(p.width, p.height) * 0.72
    }

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
        return (p.width - bay.hero) * 0.5 * (1 - bay.settle) + bay.dockX * bay.settle
    }
    y: {
        const p = bay.parent
        if (!p)
            return 0
        return (p.height - bay.hero) * 0.5 * (1 - bay.settle) + (p.height - bay.dock - bay.pad) * bay.settle
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

        UsageCore {
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
            duration: 280
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
