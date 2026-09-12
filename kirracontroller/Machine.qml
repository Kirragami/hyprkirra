import QtQuick
import "svc"

Item {
    id: space

    property bool paused: false
    property real boot: 0
    property real t: 0
    property string liveSig: "000000"
    property var ringA: [0, 0, 0, 0, 0, 0, 0]
    property var ringV: [0, 0, 0, 0, 0, 0, 0]
    property var partA: []
    property var partV: []
    property var rod: []
    property var rodT: []
    property var rodWait: []

    readonly property real hubR: Math.max(24, (Math.min(width, height) * 0.5 - 6) / 1.06)
    readonly property real hubX: width * 0.5
    readonly property real hubY: height * 0.5

    readonly property var linkPorts: [
        { r: 0.64, rw: 0.020, a: 0.40, s: 0.26 },
        { r: 0.75, rw: 0.016, a: 1.04, s: 0.19 },
        { r: 0.88, rw: 0.030, a: 1.55, s: 0.20 },
        { r: 0.65, rw: 0.022, a: 3.50, s: 0.20 },
        { r: 0.66, rw: 0.028, a: 4.55, s: 0.16 },
        { r: 0.87, rw: 0.014, a: 5.20, s: 0.12 }
    ]

    function packR(r: real): real {
        const keep = 0.22
        if (r <= keep)
            return r
        return keep + (r - keep) * (0.76 - keep) / (1.03 - keep)
    }

    function isPortSlab(p: var): bool {
        const ports = space.linkPorts
        for (let i = 0; i < ports.length; i++) {
            if (Math.abs(ports[i].r - p.r) < 0.001 && Math.abs(ports[i].a - p.a) < 0.001)
                return true
        }
        return false
    }

    function portAt(i: int): var {
        const p = space.linkPorts[i]
        if (!p)
            return {
                x: 0,
                y: 0
            }
        const rr = space.packR(p.r) * space.hubR
        const mid = p.a + p.s * 0.5
        return {
            x: space.hubX + Math.cos(mid) * rr,
            y: space.hubY + Math.sin(mid) * rr
        }
    }

    function ease(u: real): real {
        const x = Math.max(0, Math.min(1, u))
        return 1 - (1 - x) * (1 - x) * (1 - x)
    }

    function easeWipe(u: real): real {
        const x = Math.max(0, Math.min(1, u))
        return x * x * (3 - 2 * x)
    }

    function gate(a: real, b: real): real {
        if (space.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (space.boot - a) / Math.max(0.001, b - a)))
    }

    function layerG(g: int): real {
        const a = (6 - g) * 0.11
        return space.ease(space.gate(a, a + 0.14))
    }

    function slabG(seq: int, n: int): real {
        const a = (seq / Math.max(1, n)) * 0.78
        return space.easeWipe(space.gate(a, a + 0.16))
    }

    function slabFromEnd(a: real, r: real, s: real): bool {
        const u = Math.sin(a * 12.9898 + r * 78.233 + s * 37.719) * 43758.5453
        return u - Math.floor(u) >= 0.5
    }

    function stepRods(n: int): void {
        const a = space.rod.slice()
        const tgt = space.rodT.slice()
        const wait = space.rodWait.slice()
        while (a.length < n) {
            a.push(0)
            tgt.push(Math.random() < 0.55 ? 0 : Math.random())
            wait.push(Math.floor(Math.random() * 50))
        }
        for (let i = 0; i < n; i++) {
            const d = tgt[i] - a[i]
            if (Math.abs(d) < 0.006) {
                const arriving = wait[i] <= 0 && Math.abs(a[i] - tgt[i]) > 0.0005
                a[i] = tgt[i]
                if (arriving) {
                    wait[i] = 16 + Math.floor(Math.random() * 90)
                } else if (wait[i] > 0) {
                    wait[i] -= 1
                } else {
                    const u = Math.random()
                    let next = u < 0.42 ? 0 : Math.random()
                    if (Math.abs(next - tgt[i]) < 0.1)
                        next = (tgt[i] + 0.3 + Math.random() * 0.5) % 1
                    tgt[i] = next
                }
            } else {
                const k = 0.06 + (i % 5) * 0.012
                a[i] += d * k
            }
        }
        space.rod = a
        space.rodT = tgt
        space.rodWait = wait
    }

    function nudgeSpin(ang: var, vel: var, damp: real, pKick: real, amp: real): var {
        const a = ang.slice()
        const v = vel.slice()
        for (let i = 0; i < a.length; i++) {
            const layerDamp = damp + i * 0.0025
            const layerAmp = amp + Math.max(0, 5 - i) * 0.004
            let vi = v[i] * layerDamp
            const still = Math.abs(vi) < 0.001
            if (still && Math.random() < pKick)
                vi = (Math.random() * 2 - 1) * layerAmp * (0.5 + Math.random())
            else if (!still && Math.random() < pKick * 0.22)
                vi += (Math.random() * 2 - 1) * layerAmp * 0.28
            a[i] += vi
            v[i] = vi
        }
        return [a, v]
    }

    function nudgeParts(n: int): void {
        const a = space.partA.slice()
        const v = space.partV.slice()
        while (a.length < n) {
            a.push(0)
            v.push(0)
        }
        for (let i = 0; i < n; i++) {
            const h = Math.abs(Math.sin(i * 12.9898 + 78.233) * 43758.5453)
            const u = h - Math.floor(h)
            const damp = 0.935 + u * 0.045
            const pKick = 0.006 + u * 0.028
            const amp = 0.01 + (1 - u) * 0.06
            let vi = v[i] * damp
            if (Math.abs(vi) < 0.0007) {
                if (Math.random() < pKick)
                    vi = (Math.random() * 2 - 1) * amp * (0.35 + Math.random())
            } else if (Math.random() < pKick * 0.18) {
                vi += (Math.random() * 2 - 1) * amp * 0.22
            }
            a[i] += vi
            v[i] = vi
        }
        space.partA = a
        space.partV = v
    }

    Timer {
        interval: 33
        running: !space.paused && space.visible && space.width > 8 && space.boot > 0.01
        repeat: true
        onTriggered: {
            space.t += 0.033
            const rings = space.nudgeSpin(space.ringA, space.ringV, 0.96, 0.02, 0.038)
            space.ringA = rings[0]
            space.ringV = rings[1]
            space.nudgeParts(160)
            space.stepRods(160)
            plate.requestPaint()
        }
    }

    onWidthChanged: plate.requestPaint()
    onHeightChanged: plate.requestPaint()
    onBootChanged: plate.requestPaint()
    onPausedChanged: {
        if (!space.paused)
            plate.requestPaint()
    }

    Canvas {
        id: plate
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, plate.width, plate.height)
            space.paintScene(ctx, plate.width, plate.height)
        }
    }

    function paintScene(ctx: var, w: real, h: real): void {
        if (w < 16 || h < 16)
            return

        const cy = space.hubY
        const R = space.hubR
        const cx = space.hubX
        const t = space.t
        const ink = Theme.line
        const dim = Theme.lineDim
        const faint = Theme.lineFaint
        const warn = Theme.warn
        const spins = [
            space.ringA[1] || 0,
            space.ringA[2] || 0,
            space.ringA[4] || 0,
            space.ringA[5] || 0
        ]

        function throb(r) {
            const v = Math.abs(space.ringV[2] || 0)
            return 1 + 0.05 * Math.sin(t * 2.35 - r * 5.4) + Math.min(0.04, v * 1.8)
        }

        function turn(g, i) {
            return space.partA[i] || 0
        }

        ctx.save()
        ctx.beginPath()
        ctx.rect(0, 0, w, h)
        ctx.clip()
        ctx.lineJoin = "miter"
        ctx.lineCap = "butt"

        function tint(name) {
            if (name === "warn")
                return warn
            if (name === "dim")
                return dim
            if (name === "faint")
                return faint
            return ink
        }

        function pack(r) {
            const keep = 0.22
            if (r <= keep)
                return r
            return keep + (r - keep) * (0.76 - keep) / (1.03 - keep)
        }

        function ring(r, weight, col, alpha) {
            if (alpha < 0.02)
                return
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = col
            ctx.globalAlpha = alpha
            ctx.lineWidth = weight
            ctx.setLineDash([])
            ctx.stroke()
        }

        function arcLine(r, weight, a0, span, col, alpha, dashOn, dashOff) {
            if (span < 0.02 || alpha < 0.02)
                return
            ctx.beginPath()
            ctx.arc(cx, cy, r, a0, a0 + span)
            ctx.strokeStyle = col
            ctx.globalAlpha = alpha
            ctx.lineWidth = weight
            if (dashOn > 0)
                ctx.setLineDash([dashOn, dashOff])
            else
                ctx.setLineDash([])
            ctx.stroke()
            ctx.setLineDash([])
        }

        function slab(r, rw, a0, span, col, fillA, strokeA, glow, weight, inn) {
            if (span < 0.015)
                return
            const a1 = a0 + span
            const outer = r + rw
            const inner = Math.max(1.2, r - rw * (inn > 0 ? inn : 1))
            ctx.beginPath()
            ctx.arc(cx, cy, outer, a0, a1, false)
            ctx.arc(cx, cy, inner, a1, a0, true)
            ctx.closePath()
            if (fillA > 0.01) {
                ctx.fillStyle = col
                ctx.globalAlpha = 1
                ctx.fill()
            }
            if (glow > 0.01) {
                ctx.strokeStyle = col
                ctx.globalAlpha = glow
                ctx.lineWidth = (weight || 1.15) * 3.6
                ctx.stroke()
            }
            ctx.strokeStyle = col
            ctx.globalAlpha = strokeA
            ctx.lineWidth = weight || 1.15
            ctx.stroke()
        }

        function dots(r, a0, span, n, size, col, alpha) {
            if (n < 2)
                return
            ctx.fillStyle = col
            for (let i = 0; i < n; i++) {
                const a = a0 + i / (n - 1) * span
                ctx.beginPath()
                ctx.arc(cx + Math.cos(a) * r, cy + Math.sin(a) * r, size, 0, Math.PI * 2)
                ctx.globalAlpha = alpha * (i % 5 === 0 ? 1 : 0.5)
                ctx.fill()
            }
        }

        function ticks(r, a0, span, n, len, col, alpha, inward) {
            for (let i = 0; i < n; i++) {
                const a = a0 + i / Math.max(1, n - 1) * span
                const major = i % 4 === 0
                const l = major ? len : len * 0.42
                const c = Math.cos(a)
                const s = Math.sin(a)
                const r1 = inward ? r - l : r + l
                ctx.beginPath()
                ctx.moveTo(cx + c * r, cy + s * r)
                ctx.lineTo(cx + c * r1, cy + s * r1)
                ctx.strokeStyle = col
                ctx.globalAlpha = alpha * (major ? 1 : 0.35)
                ctx.lineWidth = major ? 1.1 : 0.7
                ctx.stroke()
            }
        }

        function wedges(r, a0, span, n, len, col, alpha) {
            const da = 0.03
            ctx.fillStyle = col
            for (let i = 0; i < n; i++) {
                const a = a0 + i / Math.max(1, n - 1) * span
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                ctx.lineTo(cx + Math.cos(a - da) * (r - len), cy + Math.sin(a - da) * (r - len))
                ctx.lineTo(cx + Math.cos(a + da) * (r - len), cy + Math.sin(a + da) * (r - len))
                ctx.closePath()
                ctx.globalAlpha = alpha * (i % 3 === 0 ? 0.9 : 0.4)
                ctx.fill()
            }
        }

        function hatch(r, rw, a0, span, n, col, alpha) {
            for (let i = 0; i <= n; i++) {
                const a = a0 + i / n * span
                const c = Math.cos(a)
                const s = Math.sin(a)
                ctx.beginPath()
                ctx.moveTo(cx + c * (r - rw), cy + s * (r - rw))
                ctx.lineTo(cx + c * (r + rw), cy + s * (r + rw))
                ctx.strokeStyle = col
                ctx.globalAlpha = alpha
                ctx.lineWidth = 0.8
                ctx.stroke()
            }
            arcLine(r + rw, 1, a0, span, col, alpha * 1.15, 0, 0)
            arcLine(r - rw, 1, a0, span, col, alpha * 1.15, 0, 0)
        }

        const g0 = space.layerG(0)
        const g1 = space.layerG(1)
        const g2 = space.layerG(2)
        const g3 = space.layerG(3)
        const g4 = space.layerG(4)
        const g5 = space.layerG(5)
        const g6 = space.layerG(6)

        const slabs = [
            { r: 0.80, rw: 0.09, a: 0.08, s: 1.18, f: 0, k: 0.7, c: "ink", g: 0, sp: 3, w: 1.2, out: 1 },
            { r: 0.84, rw: 0.12, a: 0.15, s: 0.38, f: 0, k: 0.82, c: "ink", g: 0, sp: 3, w: 1.25, out: 1 },
            { r: 0.82, rw: 0.11, a: 1.85, s: 0.34, f: 0, k: 0.75, c: "ink", g: 0, sp: 3, w: 1.25, out: 1 },
            { r: 0.81, rw: 0.10, a: 2.95, s: 0.55, f: 0, k: 0.5, c: "ink", g: 0, sp: 3, w: 1.15, out: 1 },
            { r: 0.85, rw: 0.15, a: 3.05, s: 0.42, f: 0, k: 0.85, c: "ink", g: 0, sp: 3, w: 1.35, out: 1 },
            { r: 0.89, rw: 0.17, a: 4.2, s: 0.36, f: 0, k: 0.85, c: "ink", g: 0, sp: 3, w: 1.4, out: 1 },
            { r: 0.86, rw: 0.14, a: 5.7, s: 0.3, f: 0, k: 0.78, c: "ink", g: 0, sp: 3, w: 1.3, out: 1 },

            { r: 0.88, rw: 0.026, a: 0.22, s: 0.18, f: 0.06, k: 0.75, c: "ink", g: 1, sp: 0, w: 1.1 },
            { r: 0.90, rw: 0.014, a: 0.05, s: 0.55, f: 0.03, k: 0.55, c: "ink", g: 1, sp: 0, w: 1.0 },
            { r: 0.86, rw: 0.062, a: 0.62, s: 0.62, f: 0.16, k: 0.95, c: "warn", g: 1, sp: 0, w: 1.35, glow: 0.14 },
            { r: 0.89, rw: 0.012, a: 0.95, s: 0.26, f: 0.02, k: 0.5, c: "dim", g: 1, sp: 0, w: 0.9 },
            { r: 0.85, rw: 0.018, a: 1.28, s: 0.72, f: 0.04, k: 0.68, c: "ink", g: 1, sp: 0, w: 1.05 },
            { r: 0.88, rw: 0.030, a: 1.55, s: 0.2, f: 0.05, k: 0.72, c: "ink", g: 1, sp: 0, w: 1.1 },
            { r: 0.91, rw: 0.010, a: 2.05, s: 1.05, f: 0.015, k: 0.42, c: "faint", g: 1, sp: 0, w: 0.9 },
            { r: 0.86, rw: 0.022, a: 2.35, s: 0.34, f: 0.05, k: 0.7, c: "ink", g: 1, sp: 0, w: 1.1 },
            { r: 0.84, rw: 0.055, a: 2.9, s: 0.16, f: 0.09, k: 0.85, c: "ink", g: 1, sp: 0, w: 1.2 },
            { r: 0.88, rw: 0.015, a: 3.15, s: 0.9, f: 0.025, k: 0.5, c: "ink", g: 1, sp: 0, w: 1.0 },
            { r: 0.85, rw: 0.058, a: 4.05, s: 0.78, f: 0.17, k: 0.95, c: "warn", g: 1, sp: 0, w: 1.4, glow: 0.16 },
            { r: 0.90, rw: 0.012, a: 4.2, s: 0.38, f: 0.02, k: 0.45, c: "dim", g: 1, sp: 0, w: 0.95 },
            { r: 0.87, rw: 0.024, a: 4.85, s: 0.24, f: 0.06, k: 0.74, c: "ink", g: 1, sp: 0, w: 1.1 },
            { r: 0.87, rw: 0.014, a: 5.2, s: 0.12, f: 0.04, k: 0.65, c: "ink", g: 1, sp: 0, w: 1.0 },
            { r: 0.89, rw: 0.020, a: 5.55, s: 0.42, f: 0.045, k: 0.7, c: "ink", g: 1, sp: 0, w: 1.05 },

            { r: 0.76, rw: 0.012, a: 0.0, s: 0.42, f: 0.03, k: 0.6, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.74, rw: 0.028, a: 0.18, s: 0.14, f: 0.07, k: 0.78, c: "ink", g: 2, sp: 2, w: 1.1 },
            { r: 0.78, rw: 0.010, a: 0.48, s: 0.2, f: 0.02, k: 0.45, c: "dim", g: 2, sp: 2, w: 0.9 },
            { r: 0.75, rw: 0.016, a: 0.72, s: 0.08, f: 0.05, k: 0.7, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.75, rw: 0.016, a: 0.86, s: 0.11, f: 0.05, k: 0.7, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.75, rw: 0.016, a: 1.04, s: 0.19, f: 0.05, k: 0.7, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.73, rw: 0.042, a: 1.35, s: 0.36, f: 0.1, k: 0.88, c: "ink", g: 2, sp: 2, w: 1.2 },
            { r: 0.77, rw: 0.011, a: 1.55, s: 0.7, f: 0.02, k: 0.4, c: "faint", g: 2, sp: 2, w: 0.85 },
            { r: 0.74, rw: 0.020, a: 2.15, s: 0.22, f: 0.06, k: 0.72, c: "ink", g: 2, sp: 2, w: 1.05 },
            { r: 0.76, rw: 0.055, a: 2.55, s: 0.68, f: 0.16, k: 0.92, c: "warn", g: 2, sp: 2, w: 1.4, glow: 0.14 },
            { r: 0.72, rw: 0.014, a: 2.7, s: 0.28, f: 0.03, k: 0.5, c: "dim", g: 2, sp: 2, w: 1.0 },
            { r: 0.75, rw: 0.018, a: 3.35, s: 0.15, f: 0.04, k: 0.65, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.75, rw: 0.010, a: 3.58, s: 0.06, f: 0.03, k: 0.55, c: "ink", g: 2, sp: 2, w: 0.9 },
            { r: 0.75, rw: 0.010, a: 3.72, s: 0.1, f: 0.03, k: 0.55, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.78, rw: 0.022, a: 3.95, s: 0.44, f: 0.05, k: 0.7, c: "ink", g: 2, sp: 2, w: 1.1 },
            { r: 0.73, rw: 0.026, a: 4.55, s: 0.7, f: 0.08, k: 0.8, c: "ink", g: 2, sp: 2, w: 1.15 },
            { r: 0.76, rw: 0.012, a: 5.15, s: 0.3, f: 0.025, k: 0.5, c: "dim", g: 2, sp: 2, w: 0.95 },
            { r: 0.74, rw: 0.018, a: 5.55, s: 0.5, f: 0.05, k: 0.72, c: "ink", g: 2, sp: 2, w: 1.05 },

            { r: 0.64, rw: 0.020, a: 0.4, s: 0.26, f: 0.06, k: 0.75, c: "ink", g: 3, sp: 1, w: 1.1 },
            { r: 0.66, rw: 0.010, a: 0.15, s: 0.8, f: 0.02, k: 0.4, c: "dim", g: 3, sp: 1, w: 0.9 },
            { r: 0.62, rw: 0.030, a: 1.1, s: 0.18, f: 0.07, k: 0.8, c: "ink", g: 3, sp: 1, w: 1.15 },
            { r: 0.64, rw: 0.014, a: 1.45, s: 0.12, f: 0.04, k: 0.65, c: "ink", g: 3, sp: 1, w: 1.0 },
            { r: 0.64, rw: 0.014, a: 1.64, s: 0.08, f: 0.04, k: 0.65, c: "ink", g: 3, sp: 1, w: 1.0 },
            { r: 0.63, rw: 0.06, a: 2.05, s: 0.72, f: 0.18, k: 0.95, c: "warn", g: 3, sp: 1, w: 1.4, glow: 0.14 },
            { r: 0.67, rw: 0.011, a: 2.2, s: 0.32, f: 0.02, k: 0.45, c: "ink", g: 3, sp: 1, w: 0.95 },
            { r: 0.61, rw: 0.016, a: 2.85, s: 0.4, f: 0.05, k: 0.7, c: "ink", g: 3, sp: 1, w: 1.05 },
            { r: 0.65, rw: 0.022, a: 3.5, s: 0.2, f: 0.05, k: 0.72, c: "ink", g: 3, sp: 1, w: 1.1 },
            { r: 0.63, rw: 0.012, a: 3.85, s: 0.95, f: 0.03, k: 0.5, c: "ink", g: 3, sp: 1, w: 1.0 },
            { r: 0.66, rw: 0.028, a: 4.55, s: 0.16, f: 0.08, k: 0.82, c: "ink", g: 3, sp: 1, w: 1.15 },
            { r: 0.62, rw: 0.018, a: 5.15, s: 0.34, f: 0.05, k: 0.7, c: "ink", g: 3, sp: 1, w: 1.05 },
            { r: 0.64, rw: 0.010, a: 5.7, s: 0.22, f: 0.03, k: 0.55, c: "dim", g: 3, sp: 1, w: 0.95 },

            { r: 0.50, rw: 0.016, a: 0.3, s: 0.42, f: 0.05, k: 0.72, c: "ink", g: 4, sp: 0, w: 1.1 },
            { r: 0.52, rw: 0.010, a: 0.85, s: 0.18, f: 0.03, k: 0.55, c: "dim", g: 4, sp: 0, w: 0.9 },
            { r: 0.48, rw: 0.024, a: 1.25, s: 0.14, f: 0.07, k: 0.8, c: "ink", g: 4, sp: 0, w: 1.15 },
            { r: 0.50, rw: 0.012, a: 1.7, s: 0.7, f: 0.03, k: 0.5, c: "ink", g: 4, sp: 0, w: 1.0 },
            { r: 0.47, rw: 0.032, a: 2.55, s: 0.22, f: 0.09, k: 0.85, c: "ink", g: 4, sp: 0, w: 1.2 },
            { r: 0.51, rw: 0.014, a: 3.05, s: 0.28, f: 0.04, k: 0.65, c: "ink", g: 4, sp: 0, w: 1.0 },
            { r: 0.49, rw: 0.042, a: 3.7, s: 0.7, f: 0.16, k: 0.92, c: "warn", g: 4, sp: 0, w: 1.35, glow: 0.12 },
            { r: 0.52, rw: 0.008, a: 4.3, s: 0.6, f: 0.02, k: 0.4, c: "faint", g: 4, sp: 0, w: 0.85 },
            { r: 0.48, rw: 0.020, a: 4.85, s: 0.16, f: 0.06, k: 0.75, c: "ink", g: 4, sp: 0, w: 1.1 },
            { r: 0.50, rw: 0.012, a: 5.4, s: 0.35, f: 0.04, k: 0.65, c: "ink", g: 4, sp: 0, w: 1.0 },

            { r: 0.36, rw: 0.014, a: 0.55, s: 0.3, f: 0.05, k: 0.7, c: "ink", g: 5, sp: 2, w: 1.05 },
            { r: 0.38, rw: 0.008, a: 0.1, s: 0.5, f: 0.02, k: 0.4, c: "dim", g: 5, sp: 2, w: 0.9 },
            { r: 0.34, rw: 0.022, a: 1.2, s: 0.16, f: 0.07, k: 0.8, c: "ink", g: 5, sp: 2, w: 1.1 },
            { r: 0.36, rw: 0.010, a: 1.55, s: 0.08, f: 0.04, k: 0.6, c: "ink", g: 5, sp: 2, w: 0.95 },
            { r: 0.36, rw: 0.010, a: 1.72, s: 0.12, f: 0.04, k: 0.6, c: "ink", g: 5, sp: 2, w: 1.0 },
            { r: 0.35, rw: 0.018, a: 2.2, s: 0.55, f: 0.06, k: 0.75, c: "ink", g: 5, sp: 2, w: 1.1 },
            { r: 0.38, rw: 0.012, a: 3.1, s: 0.22, f: 0.03, k: 0.55, c: "dim", g: 5, sp: 2, w: 0.95 },
            { r: 0.34, rw: 0.038, a: 3.6, s: 0.58, f: 0.15, k: 0.9, c: "warn", g: 5, sp: 2, w: 1.3, glow: 0.12 },
            { r: 0.37, rw: 0.010, a: 4.3, s: 0.7, f: 0.025, k: 0.45, c: "ink", g: 5, sp: 2, w: 0.95 },
            { r: 0.35, rw: 0.020, a: 5.15, s: 0.18, f: 0.06, k: 0.75, c: "ink", g: 5, sp: 2, w: 1.1 },

            { r: 0.22, rw: 0.012, a: 0.8, s: 0.35, f: 0.05, k: 0.75, c: "ink", g: 6, sp: 1, w: 1.05 },
            { r: 0.24, rw: 0.008, a: 1.4, s: 0.16, f: 0.03, k: 0.5, c: "dim", g: 6, sp: 1, w: 0.9 },
            { r: 0.21, rw: 0.018, a: 2.15, s: 0.22, f: 0.08, k: 0.85, c: "ink", g: 6, sp: 1, w: 1.15 },
            { r: 0.23, rw: 0.010, a: 2.7, s: 0.5, f: 0.03, k: 0.55, c: "ink", g: 6, sp: 1, w: 1.0 },
            { r: 0.20, rw: 0.014, a: 3.6, s: 0.18, f: 0.06, k: 0.75, c: "ink", g: 6, sp: 1, w: 1.05 },
            { r: 0.22, rw: 0.010, a: 4.2, s: 0.28, f: 0.04, k: 0.65, c: "ink", g: 6, sp: 1, w: 1.0 },
            { r: 0.21, rw: 0.032, a: 5.0, s: 0.55, f: 0.16, k: 0.92, c: "warn", g: 6, sp: 1, w: 1.3, glow: 0.12 },

            { r: 0.87, rw: 0.022, a: 0.5, s: 0.7, f: 0.05, k: 0.65, c: "ink", g: 1, sp: 0, w: 1.05 },
            { r: 0.83, rw: 0.030, a: 0.7, s: 0.35, f: 0.07, k: 0.78, c: "ink", g: 1, sp: 0, w: 1.15 },
            { r: 0.89, rw: 0.018, a: 1.4, s: 0.4, f: 0.04, k: 0.6, c: "ink", g: 1, sp: 0, w: 1.0 },
            { r: 0.84, rw: 0.026, a: 3.3, s: 0.55, f: 0.06, k: 0.72, c: "ink", g: 1, sp: 0, w: 1.1 },
            { r: 0.86, rw: 0.045, a: 4.0, s: 0.3, f: 0.08, k: 0.8, c: "ink", g: 1, sp: 0, w: 1.2 },
            { r: 0.91, rw: 0.014, a: 5.35, s: 0.65, f: 0.03, k: 0.5, c: "dim", g: 1, sp: 0, w: 0.95 },
            { r: 0.77, rw: 0.024, a: 0.1, s: 0.55, f: 0.05, k: 0.68, c: "ink", g: 2, sp: 2, w: 1.1 },
            { r: 0.72, rw: 0.018, a: 0.65, s: 0.4, f: 0.05, k: 0.65, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.79, rw: 0.016, a: 1.3, s: 0.5, f: 0.04, k: 0.6, c: "dim", g: 2, sp: 2, w: 1.0 },
            { r: 0.71, rw: 0.035, a: 2.45, s: 0.38, f: 0.08, k: 0.8, c: "ink", g: 2, sp: 2, w: 1.15 },
            { r: 0.77, rw: 0.020, a: 3.5, s: 0.48, f: 0.05, k: 0.7, c: "ink", g: 2, sp: 2, w: 1.05 },
            { r: 0.74, rw: 0.030, a: 4.6, s: 0.45, f: 0.07, k: 0.78, c: "ink", g: 2, sp: 2, w: 1.15 },
            { r: 0.78, rw: 0.014, a: 5.4, s: 0.7, f: 0.03, k: 0.5, c: "ink", g: 2, sp: 2, w: 1.0 },
            { r: 0.65, rw: 0.024, a: 0.25, s: 0.5, f: 0.06, k: 0.7, c: "ink", g: 3, sp: 1, w: 1.1 },
            { r: 0.60, rw: 0.018, a: 1.05, s: 0.4, f: 0.05, k: 0.7, c: "ink", g: 3, sp: 1, w: 1.05 },
            { r: 0.68, rw: 0.016, a: 1.95, s: 0.7, f: 0.04, k: 0.55, c: "ink", g: 3, sp: 1, w: 1.0 },
            { r: 0.62, rw: 0.026, a: 3.4, s: 0.45, f: 0.07, k: 0.75, c: "ink", g: 3, sp: 1, w: 1.1 },
            { r: 0.67, rw: 0.014, a: 4.4, s: 0.5, f: 0.04, k: 0.6, c: "dim", g: 3, sp: 1, w: 1.0 },
            { r: 0.61, rw: 0.022, a: 5.35, s: 0.4, f: 0.06, k: 0.72, c: "ink", g: 3, sp: 1, w: 1.1 },
            { r: 0.51, rw: 0.022, a: 0.2, s: 0.55, f: 0.06, k: 0.7, c: "ink", g: 4, sp: 0, w: 1.1 },
            { r: 0.46, rw: 0.016, a: 1.15, s: 0.45, f: 0.05, k: 0.65, c: "ink", g: 4, sp: 0, w: 1.05 },
            { r: 0.53, rw: 0.018, a: 2.4, s: 0.5, f: 0.05, k: 0.68, c: "ink", g: 4, sp: 0, w: 1.05 },
            { r: 0.47, rw: 0.020, a: 3.55, s: 0.38, f: 0.07, k: 0.75, c: "ink", g: 4, sp: 0, w: 1.1 },
            { r: 0.51, rw: 0.026, a: 4.7, s: 0.42, f: 0.07, k: 0.78, c: "ink", g: 4, sp: 0, w: 1.15 },
            { r: 0.37, rw: 0.018, a: 0.4, s: 0.55, f: 0.05, k: 0.65, c: "ink", g: 5, sp: 2, w: 1.05 },
            { r: 0.33, rw: 0.014, a: 2.05, s: 0.45, f: 0.05, k: 0.7, c: "ink", g: 5, sp: 2, w: 1.05 },
            { r: 0.39, rw: 0.016, a: 3.45, s: 0.5, f: 0.05, k: 0.68, c: "ink", g: 5, sp: 2, w: 1.05 },
            { r: 0.33, rw: 0.022, a: 4.9, s: 0.35, f: 0.07, k: 0.78, c: "ink", g: 5, sp: 2, w: 1.1 },

            { r: 0.84, rw: 0.088, a: 3.55, s: 0.92, f: 0.22, k: 0.95, c: "warn", g: 1, sp: 0, w: 1.6, glow: 0.18 },
            { r: 0.90, rw: 0.072, a: 5.35, s: 0.7, f: 0.2, k: 0.95, c: "warn", g: 1, sp: 0, w: 1.5, glow: 0.16 },
            { r: 0.72, rw: 0.07, a: 0.12, s: 1.05, f: 0.16, k: 0.92, c: "ink", g: 2, sp: 2, w: 1.5 },
            { r: 0.58, rw: 0.065, a: 2.15, s: 0.82, f: 0.2, k: 0.95, c: "warn", g: 3, sp: 1, w: 1.5, glow: 0.15 },
            { r: 0.80, rw: 0.08, a: 4.85, s: 0.48, f: 0.18, k: 0.92, c: "ink", g: 1, sp: 0, w: 1.45 }
        ]

        if (g0 > 0.02) {
            ring(R * pack(0.92), 0.9, faint, 0.55 * g0)
            ring(R * pack(0.695), 1.15, dim, 0.4 * g1)
            ring(R * pack(0.58), 0.85, faint, 0.55 * g2)
        }
        if (g3 > 0.02)
            ring(R * pack(0.42), 1.2, ink, 0.7 * g3)
        if (g5 > 0.02)
            ring(R * pack(0.32), 1.05, dim, 0.55 * g5)

        const plist = space.linkPorts
        const order = []
        for (let i = 0; i < slabs.length; i++) {
            if (space.isPortSlab(slabs[i]))
                continue
            order.push({
                kind: 0,
                i: i,
                g: slabs[i].g,
                a: slabs[i].a
            })
        }
        for (let i = 0; i < plist.length; i++) {
            const p = plist[i]
            order.push({
                kind: 1,
                i: i,
                g: p.r > 0.8 ? 1 : (p.r > 0.7 ? 2 : 3),
                a: p.a
            })
        }
        order.sort(function (u, v) {
            if (u.g !== v.g)
                return v.g - u.g
            return u.a - v.a
        })
        const nAll = order.length
        const seqS = []
        const seqP = []
        for (let s = 0; s < order.length; s++) {
            if (order[s].kind === 0)
                seqS[order[s].i] = s
            else
                seqP[order[s].i] = s
        }

        const fillCol = ({})
        function angHit(a0, s0, a1, s1) {
            let d = Math.abs((a0 + s0 * 0.5) - (a1 + s1 * 0.5))
            const tau = Math.PI * 2
            d = d % tau
            if (d > Math.PI)
                d = tau - d
            return d < (s0 + s1) * 0.5 + 0.08
        }
        function isSmallBox(p) {
            if (p.out)
                return false
            if (p.rw > 0.026 || p.s > 0.24 || p.s < 0.07)
                return false
            return true
        }
        function isLarge(p) {
            if (p.out)
                return false
            return (p.rw >= 0.04 || p.s >= 0.55) && p.g >= 1 && p.g <= 4
        }
        function isOuterFill(p) {
            if (!p.out)
                return false
            return p.s >= 0.28 && p.s <= 0.7 && p.rw >= 0.09
        }
        const placed = []
        function hitsPlaced(rr, rw, a, s, pad) {
            for (let k = 0; k < placed.length; k++) {
                const u = placed[k]
                if (Math.abs(u.rr - rr) < u.rw + rw + pad && angHit(a, s, u.a, u.s))
                    return true
            }
            return false
        }
        const smallCands = []
        for (let i = 0; i < slabs.length; i++) {
            const p = slabs[i]
            if (space.isPortSlab(p) || !isSmallBox(p))
                continue
            const rr = pack(p.r)
            const rw = p.rw * 1.18
            if (hitsPlaced(rr, rw, p.a, p.s, 0.022))
                continue
            const u = Math.sin(i * 12.9898 + p.a * 78.233 + p.r * 37.719) * 43758.5453
            const pick = u - Math.floor(u)
            let col = ""
            if (pick >= 0.8)
                col = "warn"
            else if (pick >= 0.55)
                col = "ink"
            else
                continue
            smallCands.push({
                i: i,
                rr: rr,
                rw: rw,
                a: p.a,
                s: p.s,
                col: col,
                pick: pick
            })
        }
        smallCands.sort(function (u, v) {
            return v.pick - u.pick
        })
        let smallInk = 0
        let smallWarn = 0
        for (let k = 0; k < smallCands.length; k++) {
            const c = smallCands[k]
            if (c.col === "warn" && smallWarn >= 4)
                continue
            if (c.col === "ink" && smallInk >= 4)
                continue
            if (hitsPlaced(c.rr, c.rw, c.a, c.s, 0.05))
                continue
            placed.push({
                rr: c.rr,
                rw: c.rw,
                a: c.a,
                s: c.s
            })
            fillCol[c.i] = c.col
            if (c.col === "warn")
                smallWarn += 1
            else
                smallInk += 1
        }
        let largePick = -1
        let largeScore = 0
        for (let i = 0; i < slabs.length; i++) {
            const p = slabs[i]
            if (space.isPortSlab(p) || fillCol[i] || !isLarge(p))
                continue
            const rr = pack(p.r)
            const rw = p.rw * 1.2
            if (hitsPlaced(rr, rw, p.a, p.s, 0.04))
                continue
            const score = p.rw * p.s
            if (score > largeScore) {
                largeScore = score
                largePick = i
            }
        }
        if (largePick >= 0) {
            const p = slabs[largePick]
            fillCol[largePick] = "ink"
            placed.push({
                rr: pack(p.r),
                rw: p.rw * 1.2,
                a: p.a,
                s: p.s
            })
        }
        const outerCands = []
        for (let i = 0; i < slabs.length; i++) {
            const p = slabs[i]
            if (space.isPortSlab(p) || fillCol[i] || !isOuterFill(p))
                continue
            const rr = p.r
            const rw = p.rw
            if (hitsPlaced(rr, rw, p.a, p.s, 0.03))
                continue
            outerCands.push({
                i: i,
                a: p.a,
                s: p.s,
                rr: rr,
                rw: rw,
                score: p.rw * Math.min(p.s, 0.55)
            })
        }
        outerCands.sort(function (u, v) {
            return v.score - u.score
        })
        let outerN = 0
        for (let k = 0; k < outerCands.length && outerN < 2; k++) {
            const c = outerCands[k]
            if (hitsPlaced(c.rr, c.rw, c.a, c.s, 0.05))
                continue
            fillCol[c.i] = "ink"
            placed.push({
                rr: c.rr,
                rw: c.rw,
                a: c.a,
                s: c.s
            })
            outerN += 1
        }

        for (let i = 0; i < slabs.length; i++) {
            const p = slabs[i]
            if (space.isPortSlab(p))
                continue
            const g = space.slabG(seqS[i], nAll)
            if (g < 0.02)
                continue
            const sp = p.s * g
            const a0 = (space.slabFromEnd(p.a, p.r, p.s) ? p.a + p.s - sp : p.a) + turn(p.g, i)
            const rr = p.out ? p.r : pack(p.r)
            const th = throb(rr)
            const rwMul = (p.out ? 1 : 1.18) * (0.985 + 0.03 * (th - 1) / 0.065)
            const fillA = fillCol[i] ? 1 : 0
            const rod = space.rod[i] || 0
            let inn = 1
            if (!fillA && p.g < 6)
                inn = 1 + rod * (p.out ? 1.15 : 2.35)
            const col = fillCol[i] === "warn" ? warn : (fillA ? ink : (p.c === "warn" ? ink : tint(p.c)))
            slab(R * rr, R * p.rw * rwMul, a0, sp, col, fillA, p.k * th, 0, p.w, inn)
        }

        for (let i = 0; i < plist.length; i++) {
            const p = plist[i]
            const g = space.slabG(seqP[i], nAll)
            if (g < 0.02)
                continue
            const sp = p.s * g
            const pg = p.r > 0.8 ? 1 : (p.r > 0.7 ? 2 : 3)
            const a0 = (space.slabFromEnd(p.a, p.r, p.s) ? p.a + p.s - sp : p.a) + turn(pg, 140 + i)
            const rr = pack(p.r)
            const th = throb(rr)
            slab(R * rr, R * p.rw * 1.18 * th, a0, sp, ink, 0, 0.75 * th, 0, 1.1, 1 + (space.rod[140 + i] || 0) * 1.6)
        }

        if (g1 > 0.02) {
            arcLine(R * pack(0.905), 1.0, 0.35 + spins[0], 1.8 * g1, dim, 0.55 * g1, 5, 4)
            arcLine(R * pack(0.905), 1.0, 3.4 + spins[0], 0.9 * g1, warn, 0.7 * g1, 5, 4)
            ticks(R * pack(0.91), 4.7 + spins[0], 0.7, 11, R * 0.024, ink, 0.65 * g1, false)
            ticks(R * pack(0.91), 1.85 + spins[0], 0.35, 6, R * 0.018, warn, 0.8 * g1, false)
        }

        if (g2 > 0.02) {
            hatch(R * pack(0.705), R * 0.02, 0.85 + spins[2], 0.42 * g2, 8, warn, 0.7 * g2)
            hatch(R * pack(0.705), R * 0.016, 4.1 + spins[2], 0.22 * g2, 5, dim, 0.4 * g2)
            wedges(R * pack(0.8), 5.6 + spins[2], 0.55, 7, R * 0.026, warn, 0.85 * g2)
            wedges(R * pack(0.8), 2.4 + spins[2], 0.28, 4, R * 0.02, ink, 0.45 * g2)
        }

        if (g3 > 0.02) {
            dots(R * pack(0.585), 0.2 + spins[1], 2.1, 22, Math.max(0.7, R * 0.0032), ink, 0.7 * g3)
            dots(R * pack(0.585), 3.6 + spins[1], 1.15, 10, Math.max(0.7, R * 0.0032), warn, 0.8 * g3)
            arcLine(R * pack(0.685), 2.6, 5.9 + spins[1], 0.85 * g4, dim, 0.28 * g3, 0, 0)
            arcLine(R * pack(0.685), 1.15, 5.9 + spins[1], 0.85 * g4, warn, 0.85 * g3, 0, 0)
        }

        if (g4 > 0.02) {
            ticks(R * pack(0.545), 2.9 + spins[0], 0.85, 14, R * 0.018, ink, 0.55 * g4, true)
            dots(R * pack(0.445), 4.8 + spins[0], 1.4, 12, Math.max(0.65, R * 0.0028), warn, 0.75 * g4)
            arcLine(R * pack(0.445), 0.95, 1.1 + spins[0], 1.6 * g4, dim, 0.5 * g4, 3, 4)
        }

        if (g5 > 0.02) {
            dots(R * pack(0.3), 0.4 + spins[2], 1.7, 16, Math.max(0.6, R * 0.0026), ink, 0.7 * g5)
            wedges(R * pack(0.4), 0.15 + spins[2], 0.4, 5, R * 0.016, warn, 0.7 * g5)
        }

        if (g6 > 0.02) {
            dots(R * 0.232, 0.35 + spins[1], 2.15, 16, Math.max(0.55, R * 0.0024), ink, 0.8 * g6)
            dots(R * 0.232, 1.15 + spins[1], 0.7, 6, Math.max(0.6, R * 0.0026), warn, 0.9 * g6)
        }

        const sealG = space.ease(space.gate(0.7, 0.92))
        if (sealG > 0.02)
            space.drawSeal(ctx, cx, cy, R, t, ink, dim, warn, sealG)

        ctx.globalAlpha = 1
        ctx.setLineDash([])
        ctx.restore()
    }

    function drawSeal(ctx: var, cx: real, cy: real, R: real, t: real, ink: var, dim: var, warn: var, g: real): void {
        const cr = R * 0.175
        const rot = space.ringA[6] || t * 0.12
        const pulse = 0.82 + 0.18 * Math.sin(t * 2.1)

        ctx.beginPath()
        ctx.arc(cx, cy, cr * 0.9, 0, Math.PI * 2)
        ctx.fillStyle = ink
        ctx.globalAlpha = 0.07 * g
        ctx.fill()

        ctx.beginPath()
        ctx.arc(cx, cy, cr, 0, Math.PI * 2)
        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.92 * g
        ctx.lineWidth = 1.3
        ctx.setLineDash([])
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(cx, cy, cr * 0.8, 0, Math.PI * 2)
        ctx.strokeStyle = dim
        ctx.globalAlpha = 0.75 * g
        ctx.lineWidth = 0.85
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(cx, cy, cr, rot, rot + 1.05)
        ctx.strokeStyle = warn
        ctx.globalAlpha = 0.95 * g * pulse
        ctx.lineWidth = 2.15
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(cx, cy, cr, rot + Math.PI * 0.92, rot + Math.PI * 0.92 + 0.62)
        ctx.stroke()

        ctx.beginPath()
        ctx.arc(cx, cy, cr * 0.8, -rot * 1.4, -rot * 1.4 + 0.7)
        ctx.lineWidth = 1.15
        ctx.globalAlpha = 0.85 * g
        ctx.stroke()

        const pip = Math.max(1.6, cr * 0.07)
        for (let i = 0; i < 4; i++) {
            const a = i * Math.PI * 0.5 + Math.PI * 0.25
            const px = cx + Math.cos(a) * cr
            const py = cy + Math.sin(a) * cr
            ctx.save()
            ctx.translate(px, py)
            ctx.rotate(Math.PI / 4)
            ctx.fillStyle = i % 2 === 0 ? warn : ink
            ctx.globalAlpha = 0.95 * g
            ctx.fillRect(-pip, -pip, pip * 2, pip * 2)
            ctx.restore()
        }

        const ticks = 8
        ctx.strokeStyle = ink
        ctx.lineWidth = 0.8
        for (let i = 0; i < ticks; i++) {
            const a = i / ticks * Math.PI * 2
            const c = Math.cos(a)
            const s = Math.sin(a)
            const r0 = cr * 0.8
            const r1 = cr * (i % 2 === 0 ? 0.68 : 0.73)
            ctx.beginPath()
            ctx.moveTo(cx + c * r0, cy + s * r0)
            ctx.lineTo(cx + c * r1, cy + s * r1)
            ctx.globalAlpha = 0.55 * g
            ctx.stroke()
        }

        space.drawMarkK(ctx, cx, cy, cr * 0.7, ink, warn, g)
    }

    function drawMarkK(ctx: var, x: real, y: real, s: real, ink: var, warn: var, g: real): void {
        ctx.save()
        ctx.lineCap = "butt"
        ctx.lineJoin = "miter"
        ctx.miterLimit = 8
        ctx.setLineDash([])

        const x0 = x - s * 0.36
        const x1 = x - s * 0.22
        const T = y - s * 0.82
        const B = y + s * 0.82
        const mid = y
        const ur = {
            x: x + s * 0.46,
            y: T + s * 0.06
        }
        const lr = {
            x: x + s * 0.5,
            y: B - s * 0.04
        }
        const w = Math.max(1.15, s * 0.055)
        const w2 = Math.max(0.9, s * 0.04)
        const pr = Math.max(1.6, s * 0.085)

        function pad(px, py, r, col, fill) {
            ctx.save()
            ctx.translate(px, py)
            ctx.rotate(Math.PI / 4)
            ctx.globalAlpha = g
            if (fill) {
                ctx.fillStyle = col
                ctx.fillRect(-r, -r, r * 2, r * 2)
            } else {
                ctx.strokeStyle = col
                ctx.lineWidth = Math.max(0.9, r * 0.32)
                ctx.strokeRect(-r, -r, r * 2, r * 2)
            }
            ctx.restore()
        }

        function via(px, py, r, col) {
            ctx.globalAlpha = g
            ctx.beginPath()
            ctx.arc(px, py, r, 0, Math.PI * 2)
            ctx.strokeStyle = col
            ctx.lineWidth = Math.max(0.9, r * 0.4)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(px, py, r * 0.32, 0, Math.PI * 2)
            ctx.fillStyle = col
            ctx.fill()
        }

        function wire(pts, width, col, glow) {
            if (glow) {
                ctx.globalAlpha = g * 0.16
                ctx.strokeStyle = col
                ctx.lineWidth = width * 2.6
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (let i = 1; i < pts.length; i++)
                    ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
            }
            ctx.globalAlpha = g
            ctx.strokeStyle = col
            ctx.lineWidth = width
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (let i = 1; i < pts.length; i++)
                ctx.lineTo(pts[i].x, pts[i].y)
            ctx.stroke()
        }

        const uElbow = {
            x: x1 + s * 0.2,
            y: mid - s * 0.08
        }
        const uElbow2 = {
            x: x0 + s * 0.22,
            y: mid - s * 0.22
        }
        const lElbow = {
            x: x1 + s * 0.22,
            y: mid + s * 0.08
        }
        const lElbow2 = {
            x: x0 + s * 0.24,
            y: mid + s * 0.22
        }

        wire([{ x: x0, y: T }, { x: x0, y: B }], w, ink, true)
        wire([{ x: x1, y: T }, { x: x1, y: B }], w2, ink, true)

        wire([
            { x: x1, y: uElbow.y },
            { x: uElbow.x, y: uElbow.y },
            { x: ur.x, y: ur.y }
        ], w, ink, true)
        wire([
            { x: x0, y: uElbow2.y },
            { x: uElbow2.x, y: uElbow2.y },
            { x: ur.x - s * 0.12, y: ur.y + s * 0.1 }
        ], w2, warn, true)

        wire([
            { x: x1, y: lElbow.y },
            { x: lElbow.x, y: lElbow.y },
            { x: lr.x, y: lr.y }
        ], w, ink, true)
        wire([
            { x: x0, y: lElbow2.y },
            { x: lElbow2.x, y: lElbow2.y },
            { x: lr.x - s * 0.1, y: lr.y - s * 0.1 }
        ], w2, ink, true)

        pad(x0, T, pr, ink, false)
        pad(x1, T, pr * 0.72, warn, true)
        pad(x0, B, pr, ink, false)
        pad(x1, B, pr * 0.72, ink, true)
        pad(ur.x, ur.y, pr, ink, false)
        pad(lr.x, lr.y, pr, warn, true)
        via(x1, mid, pr * 0.78, warn)
        via(x0, mid, pr * 0.52, ink)

        ctx.restore()
    }
}
