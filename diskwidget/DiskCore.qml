import QtQuick
import "svc"

Item {
    id: core

    property bool live: false
    property bool paused: false
    property real diskN: core.live ? Disk.pct / 100 : 0

    Behavior on diskN {
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    onDiskNChanged: canvas.requestPaint()
    onLiveChanged: canvas.requestPaint()
    onPausedChanged: {
        if (!core.paused)
            canvas.requestPaint()
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
        const rDisk = R
        const rPlat = R * 0.78
        const rPlat2 = R * 0.58
        const rHub = R * 0.22
        const rSpindle = R * 0.09
        const lw = Math.max(1.05, R * 0.02)
        const a0 = Math.PI * 0.75
        const span = Math.PI * 1.5

        ctx.lineCap = "butt"
        ctx.lineJoin = "miter"

        function ring(r: real, aStart: real, aEnd: real, ink: var, alpha: real, width: real): void {
            ctx.beginPath()
            ctx.arc(cx, cy, r, aStart, aEnd)
            ctx.strokeStyle = ink
            ctx.globalAlpha = alpha
            ctx.lineWidth = width
            ctx.stroke()
        }

        function track(r: real, u: real, ink: var, alpha: real, width: real): void {
            const v = Math.max(0, Math.min(1, u))
            if (v <= 0.001)
                return
            ring(r, a0, a0 + span * v, ink, alpha, width)
        }

        track(rDisk, 1, Theme.lineDim, 0.38, lw)

        ctx.lineCap = "butt"
        ctx.strokeStyle = Theme.lineDim
        ctx.globalAlpha = 0.34
        ctx.lineWidth = Math.max(1, lw * 0.5)
        const ticks = 12
        for (let i = 0; i <= ticks; i++) {
            const a = a0 + span * (i / ticks)
            const major = i % 3 === 0
            const t0 = rDisk * 1.01
            const t1 = rDisk * (major ? 1.08 : 1.04)
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * t0, cy + Math.sin(a) * t0)
            ctx.lineTo(cx + Math.cos(a) * t1, cy + Math.sin(a) * t1)
            ctx.stroke()
        }

        ring(rPlat, 0, Math.PI * 2, Theme.line, core.live ? 0.42 : 0.62, lw * 0.85)
        ring(rPlat2, 0, Math.PI * 2, Theme.lineDim, 0.55, lw * 0.7)
        ring(rHub, 0, Math.PI * 2, Theme.line, core.live ? 0.7 : 0.85, lw * 0.9)

        ctx.beginPath()
        ctx.arc(cx, cy, rSpindle, 0, Math.PI * 2)
        ctx.fillStyle = Theme.line
        ctx.globalAlpha = core.live ? 0.82 : 0.55
        ctx.fill()

        ctx.beginPath()
        ctx.arc(cx, cy, Math.max(1.2, rSpindle * 0.35), 0, Math.PI * 2)
        ctx.fillStyle = Theme.bg
        ctx.globalAlpha = 0.9
        ctx.fill()

        if (core.live) {
            ctx.lineCap = "round"
            track(rDisk, core.diskN, Theme.line, 0.96, lw * 1.15)

            const v = Math.max(0, Math.min(1, core.diskN))
            const a = a0 + span * v
            ctx.beginPath()
            ctx.arc(cx + Math.cos(a) * rDisk, cy + Math.sin(a) * rDisk, Math.max(1.5, lw), 0, Math.PI * 2)
            ctx.fillStyle = Theme.line
            ctx.globalAlpha = 0.95
            ctx.fill()
        }

        ctx.globalAlpha = 1
    }
}
