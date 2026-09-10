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

    property var appearOrder: [0, 1, 2, 3, 4, 5]
    property int appearSeed: 0

    function shuffleOrder(): void {
        const n = rail.padN
        const ord = []
        for (let i = 0; i < n; i++)
            ord.push(i)
        for (let i = n - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1))
            const t = ord[i]
            ord[i] = ord[j]
            ord[j] = t
        }
        rail.appearOrder = ord
        rail.appearSeed += 1
    }

    function appearRank(i: int): int {
        const _ = rail.appearSeed
        const ord = rail.appearOrder
        for (let k = 0; k < ord.length; k++) {
            if (ord[k] === i)
                return k
        }
        return i
    }

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
        const r = rail.appearRank(i)
        const a = 0.06 + r * 0.12
        const b = a + 0.2
        if (rail.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (rail.boot - a) / Math.max(0.001, b - a)))
    }

    function padReveal(i: int): real {
        const r = rail.appearRank(i)
        const a = 0.06 + r * 0.12 + 0.18
        const b = a + 0.14
        if (rail.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (rail.boot - a) / Math.max(0.001, b - a)))
    }

    onOpenChanged: {
        if (rail.open) {
            outAnim.stop()
            rail.boot = 0
            rail.shuffleOrder()
            Links.watching = true
            inAnim.restart()
        } else {
            inAnim.stop()
            Links.watching = false
            outAnim.restart()
        }
    }

    SequentialAnimation {
        id: inAnim
        PauseAnimation {
            duration: 40
        }
        NumberAnimation {
            target: rail
            property: "boot"
            to: 1
            duration: 620
            easing.type: Easing.Linear
        }
    }

    NumberAnimation {
        id: outAnim
        target: rail
        property: "boot"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
    }

    Rectangle {
        anchors.fill: parent
        opacity: rail.open ? 1 : 0
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

        Behavior on opacity {
            NumberAnimation {
                duration: rail.open ? 220 : 180
                easing.type: Easing.OutQuad
            }
        }
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

    MouseArea {
        anchors.fill: parent
        enabled: rail.open
        onClicked: rail.dismiss()
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
