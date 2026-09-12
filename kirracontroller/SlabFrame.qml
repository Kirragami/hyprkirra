pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "svc"

Item {
    id: slab

    property real reveal: 0
    property bool lit: false
    property string iconSrc: ""

    signal hovered()
    signal activated()

    readonly property real span: 0.86
    readonly property real inner: 148
    readonly property real outer: 190

    readonly property real grow: {
        const u = Math.max(0, Math.min(1, (slab.reveal - 0.2) / 0.8))
        return u * u * (3 - 2 * u)
    }

    implicitWidth: 2 * slab.outer * Math.sin(slab.span * 0.5) + 16
    implicitHeight: slab.outer - slab.inner * Math.cos(slab.span * 0.5) + 12
    width: implicitWidth
    height: implicitHeight
    opacity: slab.reveal
    visible: slab.reveal > 0.02
    scale: 0.36 + 0.64 * slab.grow
    transformOrigin: Item.Bottom

    Canvas {
        id: plate
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const span = slab.span
            const inner = slab.inner
            const outer = slab.outer
            const cx = width * 0.5
            const cy = outer + 4
            const a0 = -Math.PI * 0.5 - span * 0.5
            const a1 = -Math.PI * 0.5 + span * 0.5
            ctx.lineJoin = "miter"
            ctx.lineCap = "butt"
            ctx.beginPath()
            ctx.arc(cx, cy, outer, a0, a1, false)
            ctx.arc(cx, cy, inner, a1, a0, true)
            ctx.closePath()
            if (slab.lit) {
                ctx.fillStyle = Theme.warn
                ctx.globalAlpha = 1
                ctx.fill()
            }
            ctx.strokeStyle = Theme.line
            ctx.globalAlpha = slab.lit ? 1 : 0.78
            ctx.lineWidth = slab.lit ? 1.55 : 1.2
            ctx.stroke()
        }
    }

    Image {
        id: glyph
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: 22
        height: 22
        sourceSize.width: 22
        sourceSize.height: 22
        fillMode: Image.PreserveAspectFit
        source: slab.iconSrc
        opacity: slab.grow
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: slab.lit ? Theme.bg : Theme.line
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: slab.reveal > 0.72
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: slab.hovered()
        onClicked: slab.activated()
    }

    onLitChanged: plate.requestPaint()
}
