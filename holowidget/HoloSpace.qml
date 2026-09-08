import QtQuick
import "svc"

Item {
    id: space

    property bool paused: false
    property real boot: 0
    property real t: 0

    function ease(u: real): real {
        const x = Math.max(0, Math.min(1, u))
        return 1 - (1 - x) * (1 - x) * (1 - x)
    }

    function gate(a: real, b: real): real {
        return Math.max(0, Math.min(1, (space.boot - a) / Math.max(0.001, b - a)))
    }

    Timer {
        interval: 33
        running: !space.paused && space.visible && space.width > 8
        repeat: true
        onTriggered: {
            if (space.boot >= 1)
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
            space.paintScene(ctx, plate.width, plate.height, space.boot >= 1 ? space.t : 0, space.boot)
        }
    }

    function paintScene(ctx: var, w: real, h: real, t: real, bootAt: real): void {
        if (w < 16 || h < 16)
            return

        const cx = w * 0.5
        const cy = h * 0.44
        const scale = Math.min(w, h) * 0.52
        const camYaw = 0.22
        const camPitch = 0.5
        const dist = 3.8
        const focal = 2.55
        const ink = Theme.line
        const warn = Theme.warn
        const idle = bootAt >= 1

        function gateAt(a, b) {
            if (idle)
                return 1
            return Math.max(0, Math.min(1, (bootAt - a) / Math.max(0.001, b - a)))
        }
        function rotX(p, a) {
            const c = Math.cos(a)
            const s = Math.sin(a)
            return {
                x: p.x,
                y: p.y * c - p.z * s,
                z: p.y * s + p.z * c
            }
        }
        function rotY(p, a) {
            const c = Math.cos(a)
            const s = Math.sin(a)
            return {
                x: p.x * c + p.z * s,
                y: p.y,
                z: -p.x * s + p.z * c
            }
        }
        function proj(p) {
            const q = rotX(rotY(p, camYaw), camPitch)
            const z = q.z + dist
            const s = focal / Math.max(0.35, z)
            return {
                x: cx + q.x * s * scale,
                y: cy + q.y * s * scale,
                z: q.z,
                d: z
            }
        }
        function xz(r, y, a) {
            return {
                x: Math.cos(a) * r,
                y: y,
                z: Math.sin(a) * r
            }
        }

        const faces = []
        const edges = []

        function rgba(col, a) {
            let r = 230
            let g = 230
            let b = 230
            if (col && typeof col.r === "number") {
                r = Math.round(col.r * 255)
                g = Math.round(col.g * 255)
                b = Math.round(col.b * 255)
            } else {
                const s = String(col)
                if (s.charAt(0) === "#" && s.length >= 7) {
                    r = parseInt(s.slice(1, 3), 16)
                    g = parseInt(s.slice(3, 5), 16)
                    b = parseInt(s.slice(5, 7), 16)
                }
            }
            return "rgba(" + r + "," + g + "," + b + "," + Math.max(0, Math.min(1, a)) + ")"
        }
        function fadeD(d) {
            return Math.max(0.18, Math.min(1, 2.05 / Math.max(0.35, d)))
        }
        function emit(world, alpha, col, alpha1) {
            const pts = []
            let d = 0
            for (let i = 0; i < world.length; i++) {
                const p = proj(world[i])
                pts.push(p)
                d += p.d
            }
            const n = world.length
            const fade = fadeD(d / n)
            const a = alpha1 === undefined ? alpha * fade : alpha
            const a1 = alpha1 === undefined ? a : alpha1
            if (a < 0.02 && a1 < 0.02)
                return
            faces.push({
                pts: pts,
                a: a,
                a1: a1,
                d: d / n,
                col: col || ink
            })
        }
        function edge(a, b, weight, alpha, glow, col, alpha1) {
            const p0 = proj(a)
            const p1 = proj(b)
            const d = (p0.d + p1.d) * 0.5
            const a0 = alpha * fadeD(p0.d)
            const aEnd = (alpha1 === undefined ? alpha : alpha1) * fadeD(p1.d)
            if (a0 < 0.03 && aEnd < 0.03)
                return
            edges.push({
                a: p0,
                b: p1,
                w: weight,
                a0: a0,
                a1: aEnd,
                glow: glow,
                d: d,
                col: col || ink
            })
        }
        function hoop(R, rw, y, ht, spin, a0, span, n, fillA, wallA, caps, cull, col) {
            if (span < 0.012)
                return
            const tint = col || ink
            const r0 = R - rw
            const r1 = R + rw
            const yb = y + ht
            const core = proj({
                x: 0,
                y: y,
                z: 0
            })
            const rm = (r0 + r1) * 0.5
            function nearAmt(a) {
                const out = proj(xz(r1, y, a))
                return Math.max(0, Math.min(1, (core.d + 0.1 - out.d) / 0.28))
            }
            function farAmt(a) {
                const inn = proj(xz(r0, y, a))
                return Math.max(0, Math.min(1, (inn.d - core.d + 0.1) / 0.28))
            }
            function wallShade(a) {
                const p = proj(xz(r1, y, a))
                return wallA * (0.22 + 0.78 * nearAmt(a)) * fadeD(p.d)
            }
            function topShade(a) {
                const p = proj(xz(rm, y, a))
                return fillA * fadeD(p.d)
            }
            for (let i = 0; i < n; i++) {
                const t0 = spin + a0 + i / n * span
                const t1 = spin + a0 + (i + 1) / n * span
                const n0 = nearAmt(t0)
                const n1 = nearAmt(t1)
                const f0 = farAmt(t0)
                const f1 = farAmt(t1)
                if (fillA > 0.04)
                    emit([xz(r0, y, t0), xz(r1, y, t0), xz(r1, y, t1), xz(r0, y, t1)], topShade(t0), tint, topShade(t1))
                if (!cull || n0 > 0.02 || n1 > 0.02)
                    emit([xz(r1, y, t0), xz(r1, yb, t0), xz(r1, yb, t1), xz(r1, y, t1)], wallShade(t0), tint, wallShade(t1))
                if (!cull || f0 > 0.02 || f1 > 0.02) {
                    const inn0 = wallA * 0.28 * (cull ? Math.max(f0, 0.15) : 1) * fadeD(proj(xz(r0, y, t0)).d)
                    const inn1 = wallA * 0.28 * (cull ? Math.max(f1, 0.15) : 1) * fadeD(proj(xz(r0, y, t1)).d)
                    emit([xz(r0, y, t0), xz(r0, y, t1), xz(r0, yb, t1), xz(r0, yb, t0)], inn0, tint, inn1)
                }
                edge(xz(r1, y, t0), xz(r1, y, t1), 1.6 + rw * 10, 0.45 + 0.55 * n0, idle ? 0.18 : (0.1 + 0.22 * n0), tint, 0.45 + 0.55 * n1)
                edge(xz(r1, yb, t0), xz(r1, yb, t1), 1.05, 0.28 + 0.27 * n0, 0.04, tint, 0.28 + 0.27 * n1)
                edge(xz(r0, y, t0), xz(r0, y, t1), 0.85, 0.45, 0.05, tint)
            }
            if (caps) {
                const tA = spin + a0
                const tB = spin + a0 + span
                emit([xz(r0, y, tA), xz(r1, y, tA), xz(r1, yb, tA), xz(r0, yb, tA)], wallA, tint)
                emit([xz(r0, y, tB), xz(r0, yb, tB), xz(r1, yb, tB), xz(r1, y, tB)], wallA, tint)
                edge(xz(r1, y, tA), xz(r1, yb, tA), 1.5, 1, 0.14, tint)
                edge(xz(r1, y, tB), xz(r1, yb, tB), 1.5, 1, 0.14, tint)
                edge(xz(r0, y, tA), xz(r1, y, tA), 1.1, 0.85, 0.06, tint)
                edge(xz(r0, y, tB), xz(r1, y, tB), 1.1, 0.85, 0.06, tint)
            }
        }
        function bricks(R, rw, y, ht, spin, count, fill, alpha) {
            const slot = Math.PI * 2 / count
            const span = slot * fill
            const build = gateAt(0.05, 0.36)
            const shown = Math.min(count, Math.floor(build * count + 1e-4))
            const orangeLit = gateAt(0.38, 0.48)
            const orangeN = Math.floor((count - 1) / 8) + 1
            for (let i = 0; i < shown; i++) {
                let col = ink
                if (i % 8 === 0 && orangeLit > 0.001) {
                    const rank = i / 8
                    if (rank + 0.001 < orangeLit * orangeN)
                        col = warn
                }
                hoop(R, rw, y, ht, spin, i * slot, span, 2, alpha, alpha * 1.15, true, false, col)
            }
        }
        function ticks(R, y, spin, n, len, weight, alpha, grow) {
            const g = Math.max(0, Math.min(1, grow))
            for (let i = 0; i < n; i++) {
                const u = (i + 0.5) / n
                if (u > g)
                    continue
                const a = i / n * Math.PI * 2 + spin
                const major = i % 8 === 0
                const l = major ? len : len * 0.38
                edge(xz(R, y, a), xz(R + l, y, a), major ? weight : weight * 0.5, alpha * (major ? 1 : 0.38), major ? 0.1 : 0.02, ink)
            }
        }

        const spinBot = t * 0.055
        const spinMid = t * 0.095
        const spinTop = -t * 0.04
        const seed = 0.12

        bricks(1.16, 0.048, 0.42, 0.038, spinBot, 36, 0.56, 0.55)

        const midWhite = space.ease(gateAt(0.50, 0.68))
        const midTicks = space.ease(gateAt(0.56, 0.72))
        const midOrange = space.ease(gateAt(0.74, 0.84))
        if (midWhite > 0.02) {
            hoop(1.08, 0.06, 0.05, 0.085, spinMid, seed, Math.PI * 0.78 * midWhite, 64, 0.16, 0.75, true, true, ink)
            hoop(0.9, 0.012, 0.06, 0.016, spinMid, seed, Math.PI * 2 * midTicks, 80, 0.08, 0.4, midTicks < 0.98, true, ink)
            ticks(0.9, 0.06, spinMid + seed, 80, 0.048, 0.95, 0.82, midTicks)
        }
        if (midOrange > 0.02)
            hoop(1.08, 0.06, 0.05, 0.085, spinMid, Math.PI + seed, Math.PI * 0.78 * midOrange, 64, 0.18, 0.82, true, true, warn)

        const topWhite = space.ease(gateAt(0.86, 0.96))
        const topOrange = space.ease(gateAt(0.96, 1.0))
        if (topWhite > 0.02) {
            hoop(1.04, 0.085, -0.38, 0.11, spinTop, seed, Math.PI * 2 * topWhite, 96, 0.14, 0.78, topWhite < 0.98, true, ink)
            ticks(0.955, -0.38, spinTop + seed, 72, -0.042, 1.05, 0.85, topWhite)
        }
        if (topOrange > 0.02)
            hoop(1.04, 0.04, -0.385, 0.04, spinTop, seed + t * 0.18, Math.PI * 0.22 * topOrange, 24, 0.22, 0.9, true, true, warn)

        faces.sort(function (a, b) {
            return b.d - a.d
        })
        ctx.lineJoin = "miter"
        for (let i = 0; i < faces.length; i++) {
            const f = faces[i]
            ctx.beginPath()
            ctx.moveTo(f.pts[0].x, f.pts[0].y)
            for (let j = 1; j < f.pts.length; j++)
                ctx.lineTo(f.pts[j].x, f.pts[j].y)
            ctx.closePath()
            if (Math.abs(f.a - f.a1) < 0.02) {
                ctx.fillStyle = f.col
                ctx.globalAlpha = f.a
            } else {
                const ax = (f.pts[0].x + f.pts[1].x) * 0.5
                const ay = (f.pts[0].y + f.pts[1].y) * 0.5
                const bx = (f.pts[2].x + f.pts[3].x) * 0.5
                const by = (f.pts[2].y + f.pts[3].y) * 0.5
                const g = ctx.createLinearGradient(ax, ay, bx, by)
                g.addColorStop(0, rgba(f.col, f.a))
                g.addColorStop(1, rgba(f.col, f.a1))
                ctx.fillStyle = g
                ctx.globalAlpha = 1
            }
            ctx.fill()
        }

        edges.sort(function (a, b) {
            return b.d - a.d
        })
        ctx.lineCap = "butt"
        for (let i = 0; i < edges.length; i++) {
            const e = edges[i]
            const a1 = e.a1 === undefined ? e.a0 : e.a1
            if (e.glow > 0.01) {
                if (Math.abs(e.a0 - a1) < 0.02) {
                    ctx.strokeStyle = e.col
                    ctx.globalAlpha = e.a0 * e.glow
                } else {
                    const g = ctx.createLinearGradient(e.a.x, e.a.y, e.b.x, e.b.y)
                    g.addColorStop(0, rgba(e.col, e.a0 * e.glow))
                    g.addColorStop(1, rgba(e.col, a1 * e.glow))
                    ctx.strokeStyle = g
                    ctx.globalAlpha = 1
                }
                ctx.lineWidth = e.w * 4.2
                ctx.beginPath()
                ctx.moveTo(e.a.x, e.a.y)
                ctx.lineTo(e.b.x, e.b.y)
                ctx.stroke()
            }
            if (Math.abs(e.a0 - a1) < 0.02) {
                ctx.strokeStyle = e.col
                ctx.globalAlpha = e.a0
            } else {
                const g = ctx.createLinearGradient(e.a.x, e.a.y, e.b.x, e.b.y)
                g.addColorStop(0, rgba(e.col, e.a0))
                g.addColorStop(1, rgba(e.col, a1))
                ctx.strokeStyle = g
                ctx.globalAlpha = 1
            }
            ctx.lineWidth = Math.max(0.7, e.w)
            ctx.beginPath()
            ctx.moveTo(e.a.x, e.a.y)
            ctx.lineTo(e.b.x, e.b.y)
            ctx.stroke()
        }
    }
}
