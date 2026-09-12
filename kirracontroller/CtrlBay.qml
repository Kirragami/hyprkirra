pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: bay

    property bool paused: false
    property real appear: 0
    property real boot: 0

    readonly property real pad: 10
    readonly property real padY: 34
    readonly property real dock: 312
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real viewW: {
        const p = bay.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real viewH: {
        const p = bay.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real moduleW: {
        const usable = bay.viewW - bay.pad * 2
        const gaps = bay.clusterGap * 2
        const raw = (usable - gaps) / 3
        const minW = bay.framePad * 2 + bay.dock + 20 + 96
        return Math.max(minW, raw)
    }
    readonly property real dockX: bay.viewW - bay.pad - bay.framePad - bay.dock
    readonly property real dockY: bay.viewH - bay.dock - bay.padY

    width: bay.dock
    height: bay.dock
    x: bay.dockX
    y: bay.dockY
    opacity: bay.paused ? 0 : bay.appear
    visible: opacity > 0.02

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Machine {
        anchors.fill: parent
        paused: bay.paused || bay.appear < 0.02
        boot: bay.boot
        liveSig: "101000"
    }

    Component.onCompleted: intro.start()

    SequentialAnimation {
        id: intro
        PauseAnimation {
            duration: 80
        }
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "appear"
                to: 1
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: bay
                property: "boot"
                to: 1
                duration: 520
                easing.type: Easing.Linear
            }
        }
    }
}
