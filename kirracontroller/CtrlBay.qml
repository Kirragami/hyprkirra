pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "svc"

Item {
    id: bay

    property bool paused: false
    property real appear: 0
    property real boot: 0
    property real heat: 0
    property real fire: 0
    property real veil: 0
    property bool locked: false
    property bool armed: false
    property int selected: 0

    readonly property bool lifted: bay.armed || bay.heat > 0.01 || bay.fire > 0.01 || bay.veil > 0.01
    readonly property real pad: 10
    readonly property real padY: 34
    readonly property real dock: 312
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real slabGap: 8
    readonly property var powerActs: [
        {
            tag: "LOCK",
            arg: "lock",
            icon: "icons/lock.svg"
        },
        {
            tag: "SUSPEND",
            arg: "suspend",
            icon: "icons/suspend.svg"
        },
        {
            tag: "LOGOUT",
            arg: "exit",
            icon: "icons/logout.svg"
        },
        {
            tag: "REBOOT",
            arg: "reboot",
            icon: "icons/reboot.svg"
        },
        {
            tag: "SHUTDOWN",
            arg: "shutdown",
            icon: "icons/power.svg"
        }
    ]
    readonly property int slabCount: bay.powerActs.length
    readonly property string powerSh: `${Quickshell.env("HOME")}/.config/hypr/scripts/power.sh`
    readonly property real viewW: {
        const p = bay.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real viewH: {
        const p = bay.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real dockX: bay.viewW - bay.pad - bay.framePad - bay.dock
    readonly property real dockY: bay.viewH - bay.dock - bay.padY

    anchors.fill: parent
    opacity: (bay.paused && !bay.lifted) ? 0 : bay.appear
    visible: opacity > 0.02

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function wakePower(): void {
        retract.stop()
        stirAnim.stop()
        bay.armed = true
        bay.selected = 0
        bay.locked = false
        veilIn.restart()
        heatUp.restart()
        machine.burst()
        machine.rollMarks()
    }

    function sleep(): void {
        if (!bay.lifted)
            return
        heatUp.stop()
        stirAnim.stop()
        veilIn.stop()
        bay.armed = false
        machine.clearMarks()
        retract.restart()
    }

    function pick(dir: int): void {
        if (!bay.armed || bay.fire < 0.6)
            return
        const n = bay.slabCount
        const next = (bay.selected + dir + n) % n
        if (next === bay.selected)
            return
        bay.selected = next
        bay.stir()
    }

    function focusAt(i: int): void {
        if (!bay.armed || bay.fire < 0.6)
            return
        if (i < 0 || i >= bay.slabCount || i === bay.selected)
            return
        bay.selected = i
        bay.stir()
    }

    function confirm(): void {
        if (!bay.armed || bay.fire < 0.8)
            return
        const act = bay.powerActs[bay.selected]
        if (!act)
            return
        Command.dismiss()
        Quickshell.execDetached([bay.powerSh, act.arg])
    }

    function stir(): void {
        if (!bay.armed)
            return
        machine.rollMarks()
    }

    Canvas {
        id: dim
        z: 0
        x: machine.x - 240
        y: machine.y + 10 - (bay.slabCount + 1) * 72 - 320
        width: machine.width + 480
        height: machine.y + machine.height + 180 - dim.y
        opacity: bay.veil
        visible: opacity > 0.02
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onXChanged: requestPaint()
        onYChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width * 0.5
            const hubY = machine.y - dim.y + machine.height * 0.5
            const cy = hubY - 240
            const rx = width * 0.48
            const ry = height * 0.54
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(rx / ry, 1)
            const g = ctx.createRadialGradient(0, 0, 28, 0, 0, ry)
            g.addColorStop(0, "rgba(0,0,0,0.68)")
            g.addColorStop(0.48, "rgba(0,0,0,0.42)")
            g.addColorStop(0.78, "rgba(0,0,0,0.12)")
            g.addColorStop(1, "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(0, 0, ry, 0, Math.PI * 2)
            ctx.fillStyle = g
            ctx.fill()
            ctx.restore()
        }
    }

    Machine {
        id: machine
        x: bay.dockX
        y: bay.dockY
        width: bay.dock
        height: bay.dock
        paused: (bay.paused && !bay.lifted) || bay.appear < 0.02
        boot: bay.boot
        heat: bay.heat
        locked: bay.locked
        liveSig: "101000"
        z: 2
    }

    Repeater {
        model: bay.slabCount

        SlabFrame {
            required property int index
            readonly property real unit: Math.max(0, Math.min(1, (bay.fire - index * 0.1) / 0.58))
            readonly property real ease: unit * unit * (3 - 2 * unit)
            readonly property real destY: machine.y + 10 - (index + 1) * 72
            readonly property real originY: machine.y + 108

            x: machine.x + (machine.width - width) * 0.5
            y: originY + (destY - originY) * ease
            z: 1
            reveal: ease
            iconSrc: Qt.resolvedUrl(bay.powerActs[index].icon)
            lit: bay.armed && index === bay.selected
            onHovered: bay.focusAt(index)
            onActivated: {
                bay.selected = index
                bay.confirm()
            }
        }
    }

    Component.onCompleted: intro.start()

    NumberAnimation {
        id: veilIn
        target: bay
        property: "veil"
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

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

    SequentialAnimation {
        id: heatUp
        NumberAnimation {
            target: bay
            property: "heat"
            to: 1
            duration: 70
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 110
        }
        ScriptAction {
            script: bay.locked = true
        }
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "fire"
                to: 1
                duration: 560
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: bay
                    property: "heat"
                    to: 0
                    duration: 180
                    easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: bay.locked = false
                }
            }
        }
    }

    SequentialAnimation {
        id: stirAnim
        PauseAnimation {
            duration: 70
        }
        ScriptAction {
            script: bay.locked = true
        }
        NumberAnimation {
            target: bay
            property: "heat"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: bay.locked = false
        }
    }

    SequentialAnimation {
        id: retract
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "fire"
                to: 0
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: bay
                property: "veil"
                to: 0
                duration: 260
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: bay.locked = false
        }
        NumberAnimation {
            target: bay
            property: "heat"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
    }
}
