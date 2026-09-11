pragma ComponentBehavior: Bound

import QtQuick
import "svc"

Item {
    id: rail

    property bool open: false
    property real boot: 0

    signal dismiss()

    readonly property bool mapped: rail.open || outAnim.running || inAnim.running
    readonly property int padN: Links.nodes.length
    readonly property int padH: 48
    readonly property int padW: 214

    readonly property real leadD: 38
    readonly property real leadRun: 34

    function lastIndex(): int {
        let best = 0
        let y = -Infinity
        for (let i = 0; i < rail.padN; i++) {
            const py = machine.portAt(i).y
            if (py > y) {
                y = py
                best = i
            }
        }
        return best
    }

    function leadDownLeft(i: int): bool {
        return i === 3 || i === 4 || i === rail.lastIndex()
    }

    function padOnRight(i: int): bool {
        if (rail.leadDownLeft(i))
            return false
        return machine.portAt(i).x < machine.hubX
    }

    function padBox(i: int): var {
        const slab = machine.portAt(i)
        const d = rail.leadD
        const run = rail.leadRun
        if (rail.leadDownLeft(i)) {
            const ey = slab.y + d
            return {
                x: slab.x - d - run - rail.padW,
                y: ey - rail.padH * 0.5
            }
        }
        const ey = slab.y - d
        if (rail.padOnRight(i))
            return {
                x: slab.x + d + run,
                y: ey - rail.padH * 0.5
            }
        return {
            x: slab.x - d - run - rail.padW,
            y: ey - rail.padH * 0.5
        }
    }

    function pointerPts(i: int): var {
        const slab = machine.portAt(i)
        const box = rail.padBox(i)
        const d = rail.leadD
        if (rail.leadDownLeft(i)) {
            const ey = slab.y + d
            return [
                { x: slab.x, y: slab.y },
                { x: slab.x - d, y: ey },
                { x: box.x + rail.padW, y: ey }
            ]
        }
        const ey = slab.y - d
        if (rail.padOnRight(i))
            return [
                { x: slab.x, y: slab.y },
                { x: slab.x + d, y: ey },
                { x: box.x, y: ey }
            ]
        return [
            { x: slab.x, y: slab.y },
            { x: slab.x - d, y: ey },
            { x: box.x + rail.padW, y: ey }
        ]
    }

    function lineReveal(i: int): real {
        const a = 0.48 + i * 0.05
        if (rail.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (rail.boot - a) / 0.1))
    }

    function padReveal(i: int): real {
        const a = 0.54 + i * 0.05
        if (rail.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (rail.boot - a) / 0.08))
    }

    onOpenChanged: {
        if (rail.open) {
            outAnim.stop()
            Links.watching = true
            inAnim.duration = Math.max(1, Math.round(520 * (1 - rail.boot)))
            inAnim.restart()
        } else {
            inAnim.stop()
            Links.watching = false
            outAnim.duration = Math.max(1, Math.round(520 * rail.boot))
            outAnim.restart()
        }
    }

    NumberAnimation {
        id: inAnim
        target: rail
        property: "boot"
        to: 1
        duration: 520
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: outAnim
        target: rail
        property: "boot"
        to: 0
        duration: 520
        easing.type: Easing.Linear
    }

    Rectangle {
        anchors.fill: parent
        opacity: rail.boot
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: "#00000000"
            }
            GradientStop {
                position: 0.08
                color: "#33070707"
            }
            GradientStop {
                position: 0.28
                color: "#99070707"
            }
            GradientStop {
                position: 1.0
                color: "#e6070707"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: rail.open
        onClicked: rail.dismiss()
    }

    Machine {
        id: machine
        anchors.fill: parent
        paused: !rail.mapped
        boot: rail.boot
        liveSig: Links.liveSig
        onWidthChanged: traces.requestPaint()
        onHeightChanged: traces.requestPaint()
    }

    Canvas {
        id: traces
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, traces.width, traces.height)
            if (rail.boot < 0.04)
                return
            const ink = Theme.line
            const warn = Theme.warn
            const sig = Links.liveSig
            for (let i = 0; i < rail.padN; i++) {
                const rev = rail.lineReveal(i)
                if (rev < 0.01)
                    continue
                const on = sig.charAt(i) === "1"
                HudStroke.draw(ctx, rail.pointerPts(i), rev, on ? warn : ink)
            }
            ctx.globalAlpha = 1
        }
    }

    Repeater {
        id: padRep
        model: Links.nodes

        NodePad {
            required property var modelData
            required property int index

            x: rail.padBox(index).x
            y: rail.padBox(index).y
            joinOnLeft: rail.padOnRight(index)
            nodeId: modelData.id
            label: modelData.label
            live: Links.liveSig.charAt(index) === "1"
            busy: Links.busySig.charAt(index) === "1"
            reveal: rail.padReveal(index)
            onTapped: Links.toggle(nodeId)
        }
    }

    Connections {
        target: Links
        function onLiveSigChanged() {
            traces.requestPaint()
        }
    }

    onBootChanged: traces.requestPaint()
}
