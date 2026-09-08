import QtQuick
import "svc"

Item {
    id: wave

    property bool live: false
    property bool paused: false

    onLiveChanged: canvas.requestPaint()
    onPausedChanged: {
        if (!wave.paused)
            canvas.requestPaint()
    }

    Connections {
        target: Net
        function onGenChanged(): void {
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: !wave.paused
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: wave.paint(getContext("2d"))
    }

    function peak(list: var): real {
        let m = 0
        if (!list)
            return 0
        for (let i = 0; i < list.length; i++) {
            const v = Number(list[i]) || 0
            if (v > m)
                m = v
        }
        return m
    }

    function trace(ctx: var, list: var, w: real, h: real, maxV: real): void {
        const n = list && list.length ? list.length : 0
        if (n < 2 || w < 8 || h < 8)
            return

        const padY = Math.max(4, h * 0.10)
        const base = h - 2
        const amp = Math.max(1, base - padY)
        const step = w / Math.max(1, n - 1)
        const scale = maxV > 1 ? amp / maxV : 0

        function yAt(i: int): real {
            const v = Math.max(0, Number(list[i]) || 0)
            return base - v * scale
        }

        ctx.beginPath()
        ctx.moveTo(0, yAt(0))
        for (let i = 0; i < n - 1; i++) {
            const x0 = i * step
            const x1 = (i + 1) * step
            const y0 = yAt(i)
            const y1 = yAt(i + 1)
            const mx = (x0 + x1) * 0.5
            const my = (y0 + y1) * 0.5
            ctx.quadraticCurveTo(x0, y0, mx, my)
        }
        ctx.lineTo((n - 1) * step, yAt(n - 1))
    }

    function paint(ctx: var): void {
        const w = canvas.width
        const h = canvas.height
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        if (w < 8 || h < 8)
            return

        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        const rx = Net.rxHist
        const tx = Net.txHist
        const maxV = Math.max(wave.rootFloor(), wave.peak(rx), wave.peak(tx))

        ctx.globalAlpha = 0.18
        ctx.strokeStyle = Theme.lineFaint
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(0, h * 0.5)
        ctx.lineTo(w, h * 0.5)
        ctx.stroke()

        const live = wave.live
        ctx.globalAlpha = live ? 0.92 : 0.45
        ctx.strokeStyle = Theme.line
        ctx.lineWidth = Math.max(1.05, h * 0.06)
        wave.trace(ctx, rx, w, h, maxV)
        ctx.stroke()

        ctx.globalAlpha = live ? 0.92 : 0.45
        ctx.strokeStyle = Theme.warn
        ctx.lineWidth = Math.max(1.0, h * 0.055)
        wave.trace(ctx, tx, w, h, maxV)
        ctx.stroke()

        ctx.globalAlpha = 1
    }

    function rootFloor(): real {
        return 1024
    }
}
