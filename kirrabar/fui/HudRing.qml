import QtQuick

Canvas {
    id: ring

    property real radius: 12
    property real gapDeg: 72
    property real startDeg: -50
    property color stroke: Theme.line
    property real weight: 1.35
    property real form: 1
    property bool reverse: false
    property bool spin: true
    property bool spinClockwise: true
    property int spinMs: 5600

    implicitWidth: (radius + weight) * 2 + 4
    implicitHeight: implicitWidth

    onRadiusChanged: requestPaint()
    onGapDegChanged: requestPaint()
    onStartDegChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onWeightChanged: requestPaint()
    onFormChanged: requestPaint()
    onReverseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    RotationAnimation on rotation {
        running: ring.spin && ring.form > 0.01 && ring.visible
        from: 0
        to: ring.spinClockwise ? 360 : -360
        duration: ring.spinMs
        loops: Animation.Infinite
    }

    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        const formed = Math.max(0, Math.min(1, ring.form))
        if (formed < 0.01)
            return
        const cx = width / 2
        const cy = height / 2
        const start = ring.startDeg * Math.PI / 180
        const full = (360 - ring.gapDeg) * Math.PI / 180
        const sweep = full * formed
        ctx.strokeStyle = ring.stroke
        ctx.lineWidth = ring.weight
        ctx.lineCap = formed >= 0.999 ? "butt" : "round"
        ctx.beginPath()
        if (ring.reverse) {
            const end = start + full
            ctx.arc(cx, cy, ring.radius, end, end - sweep, true)
        } else {
            ctx.arc(cx, cy, ring.radius, start, start + sweep, false)
        }
        ctx.stroke()
    }
}
