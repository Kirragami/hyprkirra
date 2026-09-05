import QtQuick
import "svc"

Item {
    id: core

    property bool live: false
    property bool paused: false
    property real cpuN: core.live ? Usage.cpu / 100 : 0
    property real memN: core.live ? Usage.mem / 100 : 0

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
        const rCpu = R
        const rRam = R * 0.78
        const rCore = R * 0.34
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

        track(rCpu, 1, Theme.lineDim, 0.38, lw)
        track(rRam, 1, Theme.lineDim, 0.3, lw * 0.9)

        ctx.lineCap = "butt"
        ctx.strokeStyle = Theme.lineDim
        ctx.globalAlpha = 0.34
        ctx.lineWidth = Math.max(1, lw * 0.5)
        const ticks = 12
        for (let i = 0; i <= ticks; i++) {
            const a = a0 + span * (i / ticks)
            const major = i % 3 === 0
            const t0 = rCpu * 1.01
            const t1 = rCpu * (major ? 1.08 : 1.04)
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * t0, cy + Math.sin(a) * t0)
            ctx.lineTo(cx + Math.cos(a) * t1, cy + Math.sin(a) * t1)
            ctx.stroke()
        }

        const gap = 0.22
        ring(rCore, gap, Math.PI - gap, Theme.line, core.live ? 0.45 : 0.7, lw * 0.75)
        ring(rCore, Math.PI + gap, Math.PI * 2 - gap, Theme.line, core.live ? 0.45 : 0.7, lw * 0.75)
        ring(rCore * 0.55, 0, Math.PI * 2, Theme.lineDim, 0.4, lw * 0.6)

        const mark = rCore * 0.14
        ctx.beginPath()
        ctx.moveTo(cx - mark, cy)
        ctx.lineTo(cx + mark, cy)
        ctx.moveTo(cx, cy - mark)
        ctx.lineTo(cx, cy + mark)
        ctx.strokeStyle = Theme.line
        ctx.globalAlpha = 0.55
        ctx.lineWidth = Math.max(1, lw * 0.65)
        ctx.stroke()

        if (core.live) {
            ctx.lineCap = "round"
            track(rCpu, core.cpuN, Theme.line, 0.96, lw * 1.15)
            track(rRam, core.memN, Theme.warn, 0.96, lw * 1.05)

            function pip(r: real, u: real, ink: var): void {
                const v = Math.max(0, Math.min(1, u))
                const a = a0 + span * v
                ctx.beginPath()
                ctx.arc(cx + Math.cos(a) * r, cy + Math.sin(a) * r, Math.max(1.5, lw), 0, Math.PI * 2)
                ctx.fillStyle = ink
                ctx.globalAlpha = 0.95
                ctx.fill()
            }
            pip(rCpu, core.cpuN, Theme.line)
            pip(rRam, core.memN, Theme.warn)
        }

        ctx.globalAlpha = 1
    }
}
