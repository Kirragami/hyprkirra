import QtQuick

Item {
    id: overlay
    enabled: false
    property bool active: true
    property real sweepY: -16

    SequentialAnimation on sweepY {
        running: overlay.active
        loops: Animation.Infinite
        NumberAnimation {
            from: -16
            to: overlay.height + 8
            duration: 5200
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1100 }
    }

    onSweepYChanged: plate.requestPaint()
    onWidthChanged: plate.requestPaint()
    onHeightChanged: plate.requestPaint()
    onActiveChanged: plate.requestPaint()

    Canvas {
        id: plate
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height
            if (w < 8 || h < 8)
                return

            const cut = Math.min(Theme.chamfer, h / 2 - 1)
            const inset = 2.2
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
            ctx.clip()

            ctx.fillStyle = "#ffffff"
            for (let i = 0; i < Math.ceil(h / 3); i++) {
                ctx.globalAlpha = 0.028
                ctx.fillRect(0, i * 3, w, 1)
            }

            if (!overlay.active)
                return

            const gy = overlay.sweepY
            const gh = 12
            const g = ctx.createLinearGradient(0, gy, 0, gy + gh)
            g.addColorStop(0, "rgba(255,255,255,0)")
            g.addColorStop(0.5, "rgba(255,255,255,1)")
            g.addColorStop(1, "rgba(255,255,255,0)")
            ctx.globalAlpha = 0.09
            ctx.fillStyle = g
            ctx.fillRect(0, gy, w, gh)
            ctx.globalAlpha = 1
        }
    }
}
