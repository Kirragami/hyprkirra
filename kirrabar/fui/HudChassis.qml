import QtQuick

Item {
    id: chassis

    property real boot: 1

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
            const cut = Math.min(Theme.chamfer, h / 2 - 1)

            function hex(inset) {
                const x = inset
                const y = inset
                const bw = w - inset * 2
                const bh = h - inset * 2
                const c = Math.max(2, cut - inset * 0.35)
                ctx.beginPath()
                ctx.moveTo(x + c, y)
                ctx.lineTo(x + bw - c, y)
                ctx.lineTo(x + bw, y + c)
                ctx.lineTo(x + bw, y + bh - c)
                ctx.lineTo(x + bw - c, y + bh)
                ctx.lineTo(x + c, y + bh)
                ctx.lineTo(x, y + bh - c)
                ctx.lineTo(x, y + c)
                ctx.closePath()
            }

            hex(1.2)
            const g = ctx.createLinearGradient(0, 0, 0, h)
            g.addColorStop(0, "#141414")
            g.addColorStop(0.45, "#0c0c0c")
            g.addColorStop(1, "#060606")
            ctx.globalAlpha = 0.92
            ctx.fillStyle = g
            ctx.fill()
            ctx.globalAlpha = 1

            ctx.strokeStyle = Theme.line
            ctx.lineWidth = 1.9
            ctx.lineJoin = "miter"
            ctx.miterLimit = 1.6
            ctx.stroke()

            hex(4)
            ctx.strokeStyle = Theme.lineFaint
            ctx.lineWidth = 1.2
            ctx.stroke()

            hex(3.2)
            ctx.save()
            ctx.clip()

            ctx.beginPath()
            ctx.moveTo(cut + 8, h * 0.5)
            ctx.lineTo(w - cut - 8, h * 0.5)
            ctx.strokeStyle = Theme.lineFaint
            ctx.lineWidth = 1
            ctx.globalAlpha = 0.55
            ctx.stroke()
            ctx.globalAlpha = 1

            function edgeX(yy, right) {
                const c = Math.max(2, cut - 2)
                let lx
                if (yy < c)
                    lx = 3 + (c - yy)
                else if (yy > h - c)
                    lx = 3 + (yy - (h - c))
                else
                    lx = 3
                return right ? (w - lx) : lx
            }

            ctx.strokeStyle = Theme.lineDim
            ctx.lineWidth = 1
            for (let i = 0; i < 4; i++) {
                const yy = 10 + i * ((h - 20) / 3)
                const lx = edgeX(yy, false)
                const rx = edgeX(yy, true)
                ctx.beginPath()
                ctx.moveTo(lx + 4, yy)
                ctx.lineTo(lx + 10, yy)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(rx - 4, yy)
                ctx.lineTo(rx - 10, yy)
                ctx.stroke()
            }
            ctx.restore()
        }
    }

    transform: Scale {
        origin.x: chassis.width / 2
        origin.y: chassis.height / 2
        xScale: 0.18 + chassis.boot * 0.82
        yScale: 0.72 + chassis.boot * 0.28
    }

    opacity: Math.min(1, chassis.boot * 1.4)
}
