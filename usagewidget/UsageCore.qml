import QtQuick
import "svc"

Item {
    id: core

    property bool live: false
    property bool paused: false
    property real cpuN: core.live ? Usage.cpu / 100 : 0
    property real memN: core.live ? Usage.mem / 100 : 0
    property real t: 0
    property real spinA: 0
    property real spinB: 0
    property real sweep: 0

    Behavior on cpuN {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    Behavior on memN {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    onCpuNChanged: canvas.requestPaint()
    onMemNChanged: canvas.requestPaint()
    onLiveChanged: canvas.requestPaint()
    onPausedChanged: {
        if (!core.paused)
            canvas.requestPaint()
    }

    Timer {
        interval: 33
        running: !core.paused && canvas.width > 8
        repeat: true
        onTriggered: {
            const dt = 0.033
            core.t += dt
            core.spinA += dt * (0.06 + core.cpuN * 1.05)
            core.spinB -= dt * (0.05 + core.memN * 0.85)
            core.sweep += dt * (0.12 + core.cpuN * 1.65)
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: !core.paused
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: core.paint(getContext("2d"))
    }

    function paint(ctx: var): void {
        const w = canvas.width
        const h = canvas.height
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        if (w < 8 || h < 8)
            return

        const cx = w * 0.5
        const cy = h * 0.5
        const R = Math.min(w, h) * 0.46
        const cellH = Math.max(8, R * 0.12)
        const rCpu = R - cellH * 0.5
        const rRam = rCpu - cellH - Math.max(5, R * 0.06)
        const hole = Math.max(12, rRam - cellH * 0.5 - 3)
        const lw = Math.max(1.05, R * 0.02)
        const a0 = Math.PI * 0.75
        const span = Math.PI * 1.5
        const segs = 20

        ctx.lineCap = "butt"
        ctx.lineJoin = "miter"

        function cells(r: real, u: real, ink: var): void {
            const gapPx = 3
            const slot = span / segs
            const gapA = Math.min(slot * 0.35, gapPx / Math.max(1, r))
            const rOut = r + cellH * 0.5
            const rIn = r - cellH * 0.5
            const lit = Math.round(Math.max(0, Math.min(1, u)) * segs)
            ctx.lineWidth = 1
            ctx.lineJoin = "miter"
            ctx.lineCap = "butt"
            for (let i = 0; i < segs; i++) {
                const aStart = a0 + slot * i + gapA * 0.5
                const aEnd = a0 + slot * (i + 1) - gapA * 0.5
                if (aEnd <= aStart)
                    continue
                ctx.beginPath()
                ctx.arc(cx, cy, rOut, aStart, aEnd, false)
                ctx.arc(cx, cy, rIn, aEnd, aStart, true)
                ctx.closePath()
                if (i < lit) {
                    ctx.fillStyle = ink
                    ctx.globalAlpha = 0.96
                    ctx.fill()
                }
                ctx.strokeStyle = Theme.lineFaint
                ctx.globalAlpha = 1
                ctx.stroke()
            }
        }

        ctx.strokeStyle = Theme.lineDim
        ctx.globalAlpha = 0.34
        ctx.lineWidth = Math.max(1, lw * 0.5)
        const ticks = 12
        const t0 = rCpu + cellH * 0.5 + 1
        for (let i = 0; i <= ticks; i++) {
            const a = a0 + span * (i / ticks)
            const major = i % 3 === 0
            const t1 = t0 + R * (major ? 0.07 : 0.03)
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * t0, cy + Math.sin(a) * t0)
            ctx.lineTo(cx + Math.cos(a) * t1, cy + Math.sin(a) * t1)
            ctx.stroke()
        }

        core.paintHud(ctx, cx, cy, hole, lw)

        cells(rCpu, core.cpuN, Theme.line)
        cells(rRam, core.memN, Theme.warn)

        ctx.globalAlpha = 1
    }

    function paintHud(ctx: var, cx: real, cy: real, hole: real, lw: real): void {
        ctx.save()
        ctx.beginPath()
        ctx.arc(cx, cy, hole, 0, Math.PI * 2)
        ctx.clip()

        const cpu = Math.max(0, Math.min(1, core.cpuN))
        const mem = Math.max(0, Math.min(1, core.memN))
        const live = core.live
        const spinA = core.spinA
        const spinB = core.spinB
        const spinC = spinA * 0.42
        const spinD = spinB * 0.55
        const sweep = core.sweep
        const ink = Theme.line
        const dim = Theme.lineDim
        const faint = Theme.lineFaint
        const warn = Theme.warn
        const w0 = Math.max(0.9, lw * 0.65)
        const w1 = Math.max(1.05, lw * 0.95)
        const w2 = Math.max(1.2, lw * 1.2)

        function pt(a: real, r: real): var {
            return {
                x: cx + Math.cos(a) * r,
                y: cy + Math.sin(a) * r
            }
        }

        function ring(r: real, a0: real, a1: real, color: var, alpha: real, width: real, cap: string): void {
            ctx.beginPath()
            ctx.arc(cx, cy, r, a0, a1)
            ctx.strokeStyle = color
            ctx.globalAlpha = alpha
            ctx.lineWidth = width
            ctx.lineCap = cap
            ctx.stroke()
        }

        function broken(r: real, n: int, gap: real, rot: real, color: var, alpha: real, width: real): void {
            const slice = Math.PI * 2 / n
            const spanA = slice * (1 - gap)
            for (let i = 0; i < n; i++) {
                const a = rot + i * slice
                ring(r, a, a + spanA, color, alpha, width, "butt")
            }
        }

        function ticks(r: real, n: int, majorEvery: int, len: real, rot: real, color: var, alpha: real): void {
            ctx.strokeStyle = color
            ctx.globalAlpha = alpha
            ctx.lineCap = "butt"
            for (let i = 0; i < n; i++) {
                const a = rot + i / n * Math.PI * 2
                const major = i % majorEvery === 0
                const inner = r - (major ? len : len * 0.42)
                ctx.lineWidth = major ? w1 : w0
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
                ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                ctx.stroke()
            }
        }

        function poly(r: real, n: int, rot: real, color: var, alpha: real, width: real): void {
            ctx.beginPath()
            for (let i = 0; i <= n; i++) {
                const a = rot + i / n * Math.PI * 2
                const p = pt(a, r)
                if (i === 0)
                    ctx.moveTo(p.x, p.y)
                else
                    ctx.lineTo(p.x, p.y)
            }
            ctx.closePath()
            ctx.strokeStyle = color
            ctx.globalAlpha = alpha
            ctx.lineWidth = width
            ctx.lineJoin = "miter"
            ctx.stroke()
        }

        function chevron(a: real, r: real, size: real, color: var, alpha: real): void {
            const nx = Math.cos(a)
            const ny = Math.sin(a)
            const tx = -ny
            const ty = nx
            const tip = pt(a, r)
            const back = r + size
            const wing = size * 0.72
            ctx.beginPath()
            ctx.moveTo(cx + nx * back + tx * wing, cy + ny * back + ty * wing)
            ctx.lineTo(tip.x, tip.y)
            ctx.lineTo(cx + nx * back - tx * wing, cy + ny * back - ty * wing)
            ctx.strokeStyle = color
            ctx.globalAlpha = alpha
            ctx.lineWidth = w1
            ctx.lineCap = "butt"
            ctx.lineJoin = "miter"
            ctx.stroke()
        }

        function bracket(a: real, r: real, arm: real, depth: real, color: var, alpha: real): void {
            const nx = Math.cos(a)
            const ny = Math.sin(a)
            const tx = -ny
            const ty = nx
            const x0 = cx + nx * r
            const y0 = cy + ny * r
            const x1 = cx + nx * (r + depth)
            const y1 = cy + ny * (r + depth)
            ctx.beginPath()
            ctx.moveTo(x1 + tx * arm, y1 + ty * arm)
            ctx.lineTo(x0 + tx * arm, y0 + ty * arm)
            ctx.lineTo(x0 - tx * arm, y0 - ty * arm)
            ctx.lineTo(x1 - tx * arm, y1 - ty * arm)
            ctx.strokeStyle = color
            ctx.globalAlpha = alpha
            ctx.lineWidth = w1
            ctx.lineCap = "butt"
            ctx.lineJoin = "miter"
            ctx.stroke()
        }

        function pip(a: real, r: real, size: real, color: var, alpha: real, fill: bool): void {
            const p = pt(a, r)
            ctx.save()
            ctx.translate(p.x, p.y)
            ctx.rotate(a + Math.PI / 4)
            ctx.beginPath()
            ctx.rect(-size, -size, size * 2, size * 2)
            if (fill) {
                ctx.fillStyle = color
                ctx.globalAlpha = alpha
                ctx.fill()
            }
            ctx.strokeStyle = color
            ctx.globalAlpha = fill ? Math.min(1, alpha + 0.15) : alpha
            ctx.lineWidth = w0
            ctx.stroke()
            ctx.restore()
        }

        ticks(hole * 0.97, 72, 6, hole * 0.055, spinC, dim, 0.42)
        ring(hole * 0.97, 0, Math.PI * 2, faint, 0.55, w0, "butt")

        broken(hole * 0.88, 3, 0.22, spinA, ink, 0.28 + cpu * 0.58, w2)
        broken(hole * 0.80, 4, 0.38, spinB, mem > 0.02 ? warn : dim, 0.28 + mem * 0.5, w1)

        ctx.lineCap = "butt"
        ctx.strokeStyle = faint
        ctx.globalAlpha = 0.5
        ctx.lineWidth = w0
        const dots = 36
        for (let i = 0; i < dots; i++) {
            if (i % 6 === 0)
                continue
            const a = spinD + i / dots * Math.PI * 2
            const inner = hole * 0.72
            const outer = hole * 0.755
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
            ctx.lineTo(cx + Math.cos(a) * outer, cy + Math.sin(a) * outer)
            ctx.stroke()
        }

        poly(hole * 0.68, 6, spinD, dim, 0.38, w0)

        const br = hole * 0.62
        for (let i = 0; i < 4; i++)
            bracket(spinC + i * Math.PI * 0.5, br, hole * 0.055, hole * 0.045, ink, 0.72)

        for (let i = 0; i < 4; i++)
            chevron(spinA * 0.35 + Math.PI * 0.25 + i * Math.PI * 0.5, hole * 0.54, hole * 0.05, dim, 0.7)

        poly(hole * 0.50, 4, Math.PI / 4 + spinC, ink, 0.28, w0)

        const gap = hole * 0.26
        const arm = hole * 0.48
        ctx.beginPath()
        ctx.moveTo(cx - arm, cy)
        ctx.lineTo(cx - gap, cy)
        ctx.moveTo(cx + gap, cy)
        ctx.lineTo(cx + arm, cy)
        ctx.moveTo(cx, cy - arm)
        ctx.lineTo(cx, cy - gap)
        ctx.moveTo(cx, cy + gap)
        ctx.lineTo(cx, cy + arm)
        ctx.strokeStyle = dim
        ctx.globalAlpha = 0.38
        ctx.lineWidth = w0
        ctx.lineCap = "butt"
        ctx.stroke()

        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(sweep)
        const reach = hole * 0.70
        const fan = ctx.createLinearGradient(0, 0, reach, 0)
        fan.addColorStop(0, "rgba(230,230,230,0.22)")
        fan.addColorStop(0.55, "rgba(230,230,230,0.08)")
        fan.addColorStop(1, "rgba(230,230,230,0)")
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arc(0, 0, reach, -0.38, 0.02)
        ctx.closePath()
        ctx.fillStyle = fan
        ctx.globalAlpha = live ? (0.18 + cpu * 0.72) : 0.22
        ctx.fill()
        ctx.beginPath()
        ctx.moveTo(hole * 0.28, 0)
        ctx.lineTo(reach, 0)
        ctx.strokeStyle = cpu > 0.82 ? warn : ink
        ctx.globalAlpha = live ? (0.18 + cpu * 0.5) : 0.16
        ctx.lineWidth = w0
        ctx.lineCap = "round"
        ctx.stroke()
        ctx.restore()

        const vanes = 8
        const rOut = hole * 0.40
        const rIn = hole * 0.28
        const vaneSpan = Math.PI * 2 / vanes
        const lit = live ? Math.round(cpu * vanes) : 0
        for (let i = 0; i < vanes; i++) {
            const a = spinB * 0.45 + i * vaneSpan
            const a1 = a + vaneSpan * 0.62
            ctx.beginPath()
            ctx.arc(cx, cy, rOut, a, a1)
            ctx.arc(cx, cy, rIn, a1, a, true)
            ctx.closePath()
            const on = i < lit
            if (on) {
                ctx.fillStyle = cpu > 0.82 ? warn : ink
                ctx.globalAlpha = 0.22 + cpu * 0.28
                ctx.fill()
            }
            ctx.strokeStyle = on ? (cpu > 0.82 ? warn : ink) : dim
            ctx.globalAlpha = on ? 0.92 : 0.45
            ctx.lineWidth = w0
            ctx.lineJoin = "miter"
            ctx.stroke()
        }

        const pkg = hole * 0.19
        const cut = Math.max(1.6, pkg * 0.16)
        ctx.beginPath()
        ctx.moveTo(cx - pkg + cut, cy - pkg)
        ctx.lineTo(cx + pkg, cy - pkg)
        ctx.lineTo(cx + pkg, cy + pkg)
        ctx.lineTo(cx - pkg, cy + pkg)
        ctx.lineTo(cx - pkg, cy - pkg + cut)
        ctx.closePath()
        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.55 + cpu * 0.3
        ctx.lineWidth = w1
        ctx.lineJoin = "miter"
        ctx.stroke()

        const pins = 5
        const pinW = Math.max(0.9, pkg * 0.08)
        const pinL = Math.max(1.6, pkg * 0.14)
        const pinSpan = pkg * 1.55
        ctx.strokeStyle = dim
        ctx.fillStyle = dim
        ctx.globalAlpha = 0.55
        ctx.lineWidth = w0
        for (let i = 0; i < pins; i++) {
            const u = (i + 0.5) / pins - 0.5
            const x = cx + u * pinSpan
            const y = cy + u * pinSpan
            ctx.fillRect(x - pinW * 0.5, cy - pkg - pinL, pinW, pinL)
            ctx.fillRect(x - pinW * 0.5, cy + pkg, pinW, pinL)
            ctx.fillRect(cx - pkg - pinL, y - pinW * 0.5, pinL, pinW)
            ctx.fillRect(cx + pkg, y - pinW * 0.5, pinL, pinW)
        }

        const die = pkg * 0.72
        ctx.beginPath()
        ctx.rect(cx - die, cy - die, die * 2, die * 2)
        ctx.strokeStyle = faint
        ctx.globalAlpha = 0.7
        ctx.lineWidth = w0
        ctx.stroke()

        const n = 4
        const gapG = Math.max(0.8, die * 0.08)
        const cell = (die * 2 - gapG * (n + 1)) / n
        const coresOn = live ? Math.round(cpu * n * n) : 0
        ctx.lineJoin = "miter"
        for (let row = 0; row < n; row++) {
            for (let col = 0; col < n; col++) {
                const i = row * n + col
                const x = cx - die + gapG + col * (cell + gapG)
                const y = cy - die + gapG + row * (cell + gapG)
                ctx.beginPath()
                ctx.rect(x, y, cell, cell)
                const on = i < coresOn
                if (on) {
                    ctx.fillStyle = cpu > 0.82 ? warn : ink
                    ctx.globalAlpha = 0.28 + cpu * 0.45
                    ctx.fill()
                }
                ctx.strokeStyle = on ? (cpu > 0.82 ? warn : ink) : dim
                ctx.globalAlpha = on ? 0.95 : 0.5
                ctx.lineWidth = w0
                ctx.stroke()
            }
        }

        const memPips = live ? Math.round(mem * 8) : 0
        for (let i = 0; i < memPips; i++)
            pip(spinB + i / Math.max(1, memPips) * Math.PI * 2, hole * 0.80, Math.max(1.3, hole * 0.016), warn, 0.55 + mem * 0.4, true)
        if (cpu > 0.04)
            pip(sweep, hole * 0.70, Math.max(1.3, hole * 0.016), cpu > 0.82 ? warn : ink, 0.4 + cpu * 0.5, true)

        ctx.restore()
    }
}
