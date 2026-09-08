import QtQuick
import "svc"

Item {
    id: core

    property bool live: false
    property bool paused: false
    property real diskN: core.live ? Disk.pct / 100 : 0
    property real ioN: core.live ? Disk.ioPct / 100 : 0
    property real t: 0
    property real plat: 0
    property real head: 0

    Behavior on diskN {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    Behavior on ioN {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    onDiskNChanged: canvas.requestPaint()
    onIoNChanged: canvas.requestPaint()
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
            core.plat += dt * (0.02 + core.ioN * 2.55)
            core.head += dt * (0.03 + core.ioN * 1.55)
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
        const rCap = R - cellH * 0.5
        const rIo = rCap - cellH - Math.max(5, R * 0.06)
        const hole = Math.max(12, rIo - cellH * 0.5 - 3)
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
        const t0 = rCap + cellH * 0.5 + 1
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

        cells(rCap, core.diskN, Theme.line)
        cells(rIo, core.ioN, Theme.warn)

        ctx.globalAlpha = 1
    }

    function paintHud(ctx: var, cx: real, cy: real, hole: real, lw: real): void {
        ctx.save()
        ctx.beginPath()
        ctx.arc(cx, cy, hole, 0, Math.PI * 2)
        ctx.clip()

        const t = core.t
        const io = Math.max(0, Math.min(1, core.ioN))
        const cap = Math.max(0, Math.min(1, core.diskN))
        const live = core.live
        const tot = Disk.readBps + Disk.writeBps
        const writing = tot > 1 && Disk.writeBps > Disk.readBps
        const busy = live && io > 0.02
        const spin = core.plat
        const seek = Math.sin(t * (0.55 + io * 4.0)) * io * 1.25
        const head = core.head + seek
        const pulse = 0.22 + io * (0.40 + 0.38 * Math.sin(t * (1.2 + io * 3.6)))
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

        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(head)
        const reach = hole * 0.90
        const fan = ctx.createLinearGradient(0, 0, reach, 0)
        const accent = writing ? Theme.warnRgb : "230,230,230"
        fan.addColorStop(0, "rgba(" + accent + ",0.20)")
        fan.addColorStop(0.5, "rgba(" + accent + ",0.07)")
        fan.addColorStop(1, "rgba(" + accent + ",0)")
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.arc(0, 0, reach, -0.22 - io * 0.18, 0.04)
        ctx.closePath()
        ctx.fillStyle = fan
        ctx.globalAlpha = live ? (0.15 + io * 0.7) : 0.2
        ctx.fill()
        ctx.restore()

        ring(hole * 0.96, 0, Math.PI * 2, faint, 0.55, w0, "butt")
        ring(hole * 0.78, 0, Math.PI * 2, dim, 0.42, w0, "butt")
        ring(hole * 0.60, 0, Math.PI * 2, faint, 0.5, w0, "butt")

        ctx.lineCap = "butt"
        ctx.strokeStyle = dim
        ctx.globalAlpha = 0.48
        const sectors = 64
        for (let i = 0; i < sectors; i++) {
            const a = spin + i / sectors * Math.PI * 2
            const major = i % 8 === 0
            ctx.lineWidth = major ? w1 : w0
            ctx.globalAlpha = major ? 0.55 : 0.28
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * hole * 0.60, cy + Math.sin(a) * hole * 0.60)
            ctx.lineTo(cx + Math.cos(a) * hole * 0.96, cy + Math.sin(a) * hole * 0.96)
            ctx.stroke()
        }

        const bits = live ? Math.round(io * 28) : 0
        ctx.fillStyle = writing ? warn : ink
        for (let i = 0; i < bits; i++) {
            const u = i / Math.max(1, bits)
            const a = spin * 0.35 + u * Math.PI * 2 + t * io * 2.4
            ctx.globalAlpha = 0.35 + pulse
            const p = pt(a, hole * 0.69)
            const s = Math.max(1.1, hole * 0.012)
            ctx.fillRect(p.x - s, p.y - s, s * 2, s * 2)
        }

        broken(hole * 0.86, 3, 0.28, -spin * 0.35, ink, 0.28 + io * 0.48, w1)
        broken(hole * 0.52, 6, 0.42, spin * 0.55, dim, 0.28 + cap * 0.4, w0)

        const wedge = 0.10 + io * 0.16
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.arc(cx, cy, hole * 0.96, head - wedge, head + 0.03)
        ctx.closePath()
        ctx.fillStyle = writing ? warn : ink
        ctx.globalAlpha = busy ? 0.06 + io * 0.14 : 0.02
        ctx.fill()

        const hub = pt(head, hole * 0.16)
        const tip = pt(head, hole * 0.90)
        ctx.beginPath()
        ctx.moveTo(hub.x, hub.y)
        ctx.lineTo(tip.x, tip.y)
        ctx.strokeStyle = busy && writing ? warn : ink
        ctx.globalAlpha = 0.28 + io * 0.6
        ctx.lineWidth = w2
        ctx.lineCap = "round"
        ctx.stroke()

        ctx.save()
        ctx.translate(tip.x, tip.y)
        ctx.rotate(head)
        ctx.beginPath()
        ctx.rect(-Math.max(1.6, hole * 0.022), -Math.max(1.2, hole * 0.016), Math.max(3.2, hole * 0.044), Math.max(2.4, hole * 0.032))
        ctx.fillStyle = busy && writing ? warn : ink
        ctx.globalAlpha = 0.35 + io * 0.57
        ctx.fill()
        ctx.restore()

        const nand = 8
        const nandR = hole * 0.34
        const lit = live ? Math.round(io * nand) : 0
        for (let i = 0; i < nand; i++) {
            const a = -spin * 0.12 + i / nand * Math.PI * 2
            const p = pt(a, nandR)
            const on = i < lit
            ctx.save()
            ctx.translate(p.x, p.y)
            ctx.rotate(a)
            const bw = Math.max(3.2, hole * 0.055)
            const bh = Math.max(4.5, hole * 0.08)
            ctx.beginPath()
            ctx.rect(-bw * 0.5, -bh * 0.5, bw, bh)
            if (on) {
                ctx.fillStyle = i % 2 === 0 ? ink : warn
                ctx.globalAlpha = 0.18 + io * 0.35
                ctx.fill()
            }
            ctx.strokeStyle = on ? ink : dim
            ctx.globalAlpha = on ? 0.9 : 0.4
            ctx.lineWidth = w0
            ctx.stroke()
            ctx.restore()
        }

        ring(hole * 0.22, 0, Math.PI * 2, ink, 0.55 + pulse * 0.2, w1, "butt")
        ring(hole * 0.14, 0, Math.PI * 2, dim, 0.6, w0, "butt")

        ctx.beginPath()
        ctx.arc(cx, cy, Math.max(2.4, hole * 0.055), 0, Math.PI * 2)
        ctx.fillStyle = busy && writing ? warn : ink
        ctx.globalAlpha = 0.22 + pulse
        ctx.fill()
        ctx.beginPath()
        ctx.arc(cx, cy, Math.max(1.1, hole * 0.02), 0, Math.PI * 2)
        ctx.fillStyle = Theme.bg
        ctx.globalAlpha = 0.9
        ctx.fill()

        const pipA = head
        const pip = pt(pipA, hole * 0.78)
        ctx.save()
        ctx.translate(pip.x, pip.y)
        ctx.rotate(pipA + Math.PI / 4)
        const ps = Math.max(1.4, hole * 0.016)
        ctx.beginPath()
        ctx.rect(-ps, -ps, ps * 2, ps * 2)
        ctx.fillStyle = writing ? warn : ink
        ctx.globalAlpha = 0.2 + io * 0.72
        ctx.fill()
        ctx.restore()

        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(cap * Math.PI * 1.5 + Math.PI * 0.75)
        ctx.beginPath()
        ctx.moveTo(hole * 0.96, 0)
        ctx.lineTo(hole * 1.02, 0)
        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.55
        ctx.lineWidth = w1
        ctx.lineCap = "butt"
        ctx.stroke()
        ctx.restore()

        ctx.restore()
    }
}
