import QtQuick

Canvas {
    id: wave

    property real peak: 0
    property real collapse: 1
    property real t: 0
    property color ink: Theme.text
    property bool live: false

    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onInkChanged: requestPaint()
    onPeakChanged: requestPaint()
    onCollapseChanged: requestPaint()

    Timer {
        interval: 16
        running: wave.live || wave.collapse < 0.995
        repeat: true
        onTriggered: {
            wave.t += 0.016
            wave.requestPaint()
        }
    }

    function hash(n: real): real {
        const s = Math.sin(n * 12.9898) * 43758.5453
        return s - Math.floor(s)
    }

    function pinch(u: real): real {
        const s = Math.sin(Math.PI * Math.max(0, Math.min(1, u)))
        return s * s
    }

    function band(i: int, n: int, t: real, env: real): real {
        const u = n <= 1 ? 0.5 : i / (n - 1)
        const gate = wave.pinch(u)
        const pulse = 0.42 + 0.58 * (0.5 + 0.5 * Math.sin(t * (2.1 + i * 0.11) + i * 0.73))
        const tone = 0.55 + 0.45 * wave.hash(i * 3.17)
        return env * gate * pulse * tone
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width
        const h = height
        if (w < 8 || h < 6)
            return

        const cy = h * 0.5
        const breath = 0.16 + 0.07 * Math.sin(wave.t * 1.6)
        const env = Math.max(0.1, Math.min(1, wave.peak * 1.45 + breath)) * wave.collapse
        const span = h * 0.46
        const t = wave.t
        const bars = Math.max(22, Math.round(w / 3.4))

        ctx.globalCompositeOperation = "source-over"
        ctx.lineCap = "butt"
        ctx.strokeStyle = wave.ink
        ctx.lineWidth = 1
        for (let i = 0; i < bars; i++) {
            const u = bars === 1 ? 0.5 : i / (bars - 1)
            const x = 1 + u * (w - 2)
            const v = wave.band(i, bars, t, env)
            const bh = Math.max(1, v * span * (0.85 + 0.35 * wave.hash(i * 1.9)))
            ctx.globalAlpha = 0.16 + v * 0.28
            ctx.beginPath()
            ctx.moveTo(x, cy - bh)
            ctx.lineTo(x, cy + bh)
            ctx.stroke()
        }

        const n = Math.max(28, Math.round(w / 2.6))
        const tops = []
        for (let i = 0; i <= n; i++) {
            const u = i / n
            const gate = wave.pinch(u)
            let jag = 0.62
            jag += Math.sin(u * Math.PI * 14) * 0.12 * Math.cos(t * 2.8)
            jag += Math.sin(u * Math.PI * 27) * 0.08 * Math.cos(t * 4.4 + 0.7)
            jag += (wave.hash(i * 2.4 + Math.floor(t * 6) * 0.17) - 0.5) * 0.16
            const v = Math.max(0.04, jag) * env * gate
            tops.push({ x: u * w, y: cy - v * span })
        }

        ctx.beginPath()
        ctx.moveTo(tops[0].x, cy)
        for (let i = 0; i < tops.length; i++)
            ctx.lineTo(tops[i].x, tops[i].y)
        for (let i = tops.length - 1; i >= 0; i--)
            ctx.lineTo(tops[i].x, cy + (cy - tops[i].y))
        ctx.closePath()

        ctx.globalAlpha = 0.18
        ctx.fillStyle = wave.ink
        ctx.fill()
        ctx.globalAlpha = 0.55
        ctx.fill()
        ctx.globalAlpha = 0.95
        ctx.lineJoin = "round"
        ctx.lineWidth = 1.2
        ctx.stroke()

        ctx.globalAlpha = 1
    }
}
