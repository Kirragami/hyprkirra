import QtQuick
import "svc"

Item {
    id: space

    property bool paused: false
    property real boot: 0
    property real t: 0
    property string liveSig: "000000"

    readonly property real hubR: height * 0.4
    readonly property real hubX: width - hubR * 0.5
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
        const keep = 0.17
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

    Timer {
        interval: 33
        running: !space.paused && space.visible && space.width > 8 && space.boot > 0.01
        repeat: true
        onTriggered: {
            space.t += 0.033
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

        const cy = h * 0.5
        const R = h * 0.4
        const cx = w - R * 0.5
        const t = space.t
        const ink = Theme.line
        const dim = Theme.lineDim
        const faint = Theme.lineFaint
        const warn = Theme.warn
        const spins = [t * 0.028, -t * 0.017, t * 0.041, -t * 0.011]

        function throb(r) {
            return 1 + 0.065 * Math.sin(t * 2.35 - r * 5.4)
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
            const keep = 0.17
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

        function slab(r, rw, a0, span, col, fillA, strokeA, glow, weight) {
            if (span < 0.015)
                return
            const a1 = a0 + span
            ctx.beginPath()
            ctx.arc(cx, cy, r + rw, a0, a1, false)
            ctx.arc(cx, cy, r - rw, a1, a0, true)
            ctx.closePath()
            if (fillA > 0.01) {
                ctx.fillStyle = col
                ctx.globalAlpha = fillA
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
            ring(R * pack(0.29), 1.05, dim, 0.55 * g5)

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

        for (let i = 0; i < slabs.length; i++) {
            const p = slabs[i]
            if (space.isPortSlab(p))
                continue
            const g = space.slabG(seqS[i], nAll)
            if (g < 0.02)
                continue
            const sp = p.s * g
            const a0 = space.slabFromEnd(p.a, p.r, p.s) ? p.a + p.s - sp : p.a
            const rr = p.out ? p.r : pack(p.r)
            const th = throb(rr)
            const rwMul = (p.out ? 1 : 1.18) * (0.985 + 0.03 * (th - 1) / 0.065)
            slab(R * rr, R * p.rw * rwMul, a0, sp, tint(p.c), p.f * (p.f > 0 ? 1.25 * th : 0), p.k * th, (p.glow || 0) * th, p.w)
        }

        for (let i = 0; i < plist.length; i++) {
            const p = plist[i]
            const on = space.liveSig.charAt(i) === "1"
            const g = space.slabG(seqP[i], nAll)
            if (g < 0.02)
                continue
            const sp = p.s * g
            const a0 = space.slabFromEnd(p.a, p.r, p.s) ? p.a + p.s - sp : p.a
            const rr = pack(p.r)
            const th = throb(rr)
            const col = on ? warn : ink
            slab(R * rr, R * p.rw * 1.18 * th, a0, sp, col, (on ? 0.32 : 0.05) * th, (on ? 0.95 : 0.75) * th, (on ? 0.16 : 0), on ? 1.4 : 1.1)
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
            dots(R * 0.16, 0.35 + spins[1], 2.15, 16, Math.max(0.55, R * 0.0024), ink, 0.8 * g6)
            dots(R * 0.16, 1.15 + spins[1], 0.7, 6, Math.max(0.6, R * 0.0026), warn, 0.9 * g6)
        }

        ctx.globalAlpha = 1
        ctx.setLineDash([])
        ctx.restore()
    }
}
