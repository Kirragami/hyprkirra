import QtQuick
import "."

Item {
    id: blade

    Canvas {
        id: plate
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height
            const br = 42
            const bl = 10
            const tl = 6

            function slab(inset) {
                const x = inset
                const y = inset
                const bw = w - inset * 2
                const bh = h - inset * 2
                const r = Math.max(8, br - inset)
                const l = Math.max(2, bl - inset * 0.4)
                const t = Math.max(2, tl - inset * 0.3)
                ctx.beginPath()
                ctx.moveTo(x + t, y)
                ctx.lineTo(x + bw, y)
                ctx.lineTo(x + bw, y + bh - r)
                ctx.lineTo(x + bw - r, y + bh)
                ctx.lineTo(x + l, y + bh)
                ctx.lineTo(x, y + bh - l)
                ctx.lineTo(x, y + t)
                ctx.closePath()
            }

            slab(0.5)
            const g = ctx.createLinearGradient(0, 0, w * 0.2, h)
            g.addColorStop(0, "#121212")
            g.addColorStop(0.55, "#0b0b0b")
            g.addColorStop(1, "#050505")
            ctx.globalAlpha = 0.94
            ctx.fillStyle = g
            ctx.fill()
            ctx.globalAlpha = 1
            ctx.strokeStyle = Theme.line
            ctx.lineWidth = 1.2
            ctx.lineJoin = "miter"
            ctx.stroke()

            slab(4)
            ctx.strokeStyle = Theme.lineFaint
            ctx.lineWidth = 1
            ctx.stroke()

            ctx.strokeStyle = Theme.lineDim
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(1, 14)
            ctx.lineTo(1, h - 18)
            ctx.stroke()

            ctx.strokeStyle = Theme.line
            ctx.lineWidth = 1
            for (let i = 0; i < 5; i++) {
                const yy = 16 + i * ((h - 36) / 4)
                ctx.beginPath()
                ctx.moveTo(1, yy)
                ctx.lineTo(8, yy)
                ctx.stroke()
            }

            ctx.strokeStyle = Theme.line
            ctx.lineWidth = 1.1
            ctx.beginPath()
            ctx.moveTo(w - br + 6, h - 1)
            ctx.lineTo(w - 1, h - br + 6)
            ctx.stroke()

            ctx.fillStyle = Theme.line
            ctx.fillRect(w - 9, 6, 4, 4)
        }
    }
}
