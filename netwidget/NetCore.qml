import QtQuick
import "svc"

Item {
    id: core

    property bool live: false
    property bool paused: false
    property real rxN: core.live ? Net.rxN : 0
    property real txN: core.live ? Net.txN : 0
    property real flow: 0
    property real beam: 0
    property real tape: 0

    Behavior on rxN {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    Behavior on txN {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    onRxNChanged: canvas.requestPaint()
    onTxNChanged: canvas.requestPaint()
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
            core.flow += 0.16
            core.beam += 0.042
            core.tape += 1.05
            if (core.flow > 256)
                core.flow -= 256
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
        const rRx = R - cellH * 0.5
        const rTx = rRx - cellH - Math.max(5, R * 0.06)
        const hole = Math.max(12, rTx - cellH * 0.5 - 3)
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
        const t0 = rRx + cellH * 0.5 + 1
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

        cells(rRx, core.rxN, Theme.line)
        cells(rTx, core.txN, Theme.warn)

        ctx.globalAlpha = 1
    }

    function paintHud(ctx: var, cx: real, cy: real, hole: real, lw: real): void {
        ctx.save()
        ctx.beginPath()
        ctx.arc(cx, cy, hole, 0, Math.PI * 2)
        ctx.clip()

        const rx = Math.max(0, Math.min(1, core.rxN))
        const tx = Math.max(0, Math.min(1, core.txN))
        const rxBps = core.live ? Net.rxBps : 0
        const txBps = core.live ? Net.txBps : 0
        const ink = Theme.line
        const dim = Theme.lineDim
        const faint = Theme.lineFaint
        const warn = Theme.warn
        const w0 = Math.max(0.9, lw * 0.65)
        const w1 = Math.max(1.05, lw * 0.95)
        const flow = core.flow
        const beamT = core.beam
        const lanes = 6
        const s = hole * 0.38
        const outer = hole * 1.25

        function frac(v: real): real {
            let u = v % 1
            if (u < 0)
                u += 1
            return u
        }

        function shotsFor(bps: real): int {
            if (bps < 1024)
                return 0
            if (bps < 20 * 1024)
                return 1
            if (bps < 80 * 1024)
                return 2
            if (bps < 320 * 1024)
                return 4
            if (bps < 1024 * 1024)
                return 7
            if (bps < 3 * 1024 * 1024)
                return 11
            if (bps < 6 * 1024 * 1024)
                return 16
            return 22
        }

        function beamSpeed(bps: real): real {
            if (bps < 20 * 1024)
                return 0.7
            const n = Math.log2(1 + bps / (48 * 1024))
            return 0.7 + Math.min(2.1, n * 0.28)
        }

        function hash(n: int): int {
            let x = n | 0
            x = Math.imul(x, 1664525) + 1013904223
            x = x ^ (x >>> 13)
            x = Math.imul(x, 1103515245) + 12345
            return x & 0x7fffffff
        }

        function laneY(i: int): real {
            return Math.round(cy + ((i + 0.5) / lanes - 0.5) * 2 * s * 0.78) + 0.5
        }

        function chamfer(half: real, cut: real): void {
            ctx.beginPath()
            ctx.moveTo(cx - half + cut, cy - half)
            ctx.lineTo(cx + half - cut, cy - half)
            ctx.lineTo(cx + half, cy - half + cut)
            ctx.lineTo(cx + half, cy + half - cut)
            ctx.lineTo(cx + half - cut, cy + half)
            ctx.lineTo(cx - half + cut, cy + half)
            ctx.lineTo(cx - half, cy + half - cut)
            ctx.lineTo(cx - half, cy - half + cut)
            ctx.closePath()
        }

        function stream(x0: real, x1: real, color: var, bps: real, salt: int): void {
            const shots = shotsFor(bps)
            const bit = shots > 10 ? 0.04 : 0.06
            const gap = shots <= 2 ? 1.618 : (0.18 + 1.15 / shots)
            const spd = beamSpeed(bps)
            for (let i = 0; i < lanes; i++) {
                const y = laneY(i)
                ctx.beginPath()
                ctx.moveTo(x0, y)
                ctx.lineTo(x1, y)
                ctx.strokeStyle = color
                ctx.globalAlpha = 0.18
                ctx.lineWidth = w0
                ctx.lineCap = "butt"
                ctx.stroke()
            }
            for (let p = 0; p < shots; p++) {
                const u = beamT * spd + p * gap
                const t = frac(u)
                const lane = hash(Math.floor(u) * 31 + p * 17 + salt) % lanes
                const y = laneY(lane)
                const x = x0 + (x1 - x0) * t
                const xA = x0 + (x1 - x0) * Math.max(0, t - bit)
                const xB = x0 + (x1 - x0) * Math.min(1, t + bit)
                ctx.beginPath()
                ctx.moveTo(xA, y)
                ctx.lineTo(xB, y)
                ctx.strokeStyle = color
                ctx.globalAlpha = 0.88
                ctx.lineWidth = w0
                ctx.lineCap = "butt"
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(x, y, Math.max(1.15, w0 * 0.85), 0, Math.PI * 2)
                ctx.fillStyle = color
                ctx.globalAlpha = 0.95
                ctx.fill()
            }
        }

        stream(cx - outer, cx - s, ink, rxBps, 19)
        stream(cx + s, cx + outer, warn, txBps, 73)

        chamfer(s, s * 0.22)
        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.82
        ctx.lineWidth = w1
        ctx.lineJoin = "miter"
        ctx.stroke()

        const s2 = s * 0.62
        chamfer(s2, s2 * 0.18)
        ctx.strokeStyle = dim
        ctx.globalAlpha = 0.7
        ctx.lineWidth = w0
        ctx.stroke()

        ctx.save()
        chamfer(s2, s2 * 0.18)
        ctx.clip()
        const scanY = cy - s2 + frac(flow * 0.07) * s2 * 2
        const band = ctx.createLinearGradient(0, scanY - 7, 0, scanY + 7)
        band.addColorStop(0, "rgba(230,230,230,0)")
        band.addColorStop(0.5, "rgba(230,230,230,0.22)")
        band.addColorStop(1, "rgba(230,230,230,0)")
        ctx.fillStyle = band
        ctx.globalAlpha = 0.85
        ctx.fillRect(cx - s2, scanY - 7, s2 * 2, 14)
        ctx.restore()

        ctx.beginPath()
        ctx.moveTo(cx, cy - s2)
        ctx.lineTo(cx, cy + s2)
        ctx.strokeStyle = faint
        ctx.globalAlpha = 0.55 + 0.25 * (0.5 + 0.5 * Math.sin(flow * 0.9))
        ctx.lineWidth = w0
        ctx.stroke()

        const g = Math.max(2.4, s2 * 0.22)
        ctx.strokeStyle = dim
        ctx.lineWidth = w0
        for (let i = -1; i <= 1; i++) {
            ctx.globalAlpha = 0.35 + 0.35 * frac(flow * 0.11 + i * 0.33)
            ctx.beginPath()
            ctx.moveTo(cx - s2 * 0.55, cy + i * g)
            ctx.lineTo(cx + s2 * 0.55, cy + i * g)
            ctx.stroke()
        }
        for (let i = -1; i <= 1; i++) {
            ctx.globalAlpha = 0.35 + 0.35 * frac(flow * 0.11 + 0.5 + i * 0.33)
            ctx.beginPath()
            ctx.moveTo(cx + i * g, cy - s2 * 0.55)
            ctx.lineTo(cx + i * g, cy + s2 * 0.55)
            ctx.stroke()
        }

        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(flow * 0.18)
        const d = s2 * 0.28
        ctx.beginPath()
        ctx.moveTo(0, -d)
        ctx.lineTo(d, 0)
        ctx.lineTo(0, d)
        ctx.lineTo(-d, 0)
        ctx.closePath()
        ctx.strokeStyle = ink
        ctx.globalAlpha = 0.45 + Math.max(rx, tx) * 0.4
        ctx.lineWidth = w0
        ctx.stroke()
        ctx.restore()

        const arm = s * 0.14
        const inset = s * 0.07
        ctx.strokeStyle = ink
        ctx.lineWidth = w1
        const corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]]
        for (let i = 0; i < 4; i++) {
            const ox = cx + corners[i][0] * (s + inset)
            const oy = cy + corners[i][1] * (s + inset)
            ctx.globalAlpha = 0.4 + 0.45 * (0.5 + 0.5 * Math.sin(flow * 1.1 + i * 1.57))
            ctx.beginPath()
            ctx.moveTo(ox, oy + corners[i][1] * arm)
            ctx.lineTo(ox, oy)
            ctx.lineTo(ox + corners[i][0] * arm, oy)
            ctx.stroke()
        }

        ctx.fillStyle = ink
        ctx.globalAlpha = 0.28 + rx * 0.55
        ctx.fillRect(cx - s2 * 0.42, cy - 1.2, s2 * 0.32, 2.4)
        ctx.fillStyle = warn
        ctx.globalAlpha = 0.28 + tx * 0.55
        ctx.fillRect(cx + s2 * 0.10, cy - 1.2, s2 * 0.32, 2.4)

        ctx.save()
        const px = Math.max(8, Math.round(s * 0.15))
        ctx.font = px + "px \"" + Theme.fontMono + "\""
        ctx.textBaseline = "middle"
        ctx.textAlign = "left"
        const step = px * 0.70

        function bitAt(i: int, salt: int): string {
            return (hash(Math.imul(i, 2654435761) + salt) & 1) ? "1" : "0"
        }

        function binRow(y: real, color: var, bps: real, salt: int): void {
            if (bps < 1024)
                return
            const fade = Math.min(1, bps / 8192)
            const half = s * 0.86
            const off = core.tape
            const shift = ((off % step) + step) % step
            let x = cx - half + shift - step
            let gi = -Math.floor(off / step) - 1
            ctx.save()
            ctx.beginPath()
            ctx.rect(cx - half, y - px, half * 2, px * 2)
            ctx.clip()
            ctx.fillStyle = color
            ctx.globalAlpha = 0.55 + fade * 0.35
            while (x < cx + half + step) {
                ctx.fillText(bitAt(gi, salt), x, y)
                x += step
                gi += 1
            }
            ctx.restore()
        }

        binRow(cy - s - px * 0.62, ink, rxBps, 7)
        binRow(cy + s + px * 0.62, warn, txBps, 91)
        ctx.restore()

        ctx.restore()
    }
}
