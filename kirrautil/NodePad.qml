pragma ComponentBehavior: Bound

import QtQuick
import "svc"

Item {
    id: pad

    property string nodeId: ""
    property string label: ""
    property bool live: false
    property bool busy: false
    property real reveal: 1
    property bool joinOnLeft: false

    readonly property bool hot: hover.containsMouse

    signal tapped()

    width: 214
    height: 48
    visible: pad.reveal > 0.001

    Item {
        id: wipe
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: pad.width * pad.reveal
        x: pad.joinOnLeft ? 0 : pad.width * (1 - pad.reveal)
        clip: true

        Item {
            id: body
            width: pad.width
            height: pad.height
            x: pad.joinOnLeft ? 0 : pad.width * (pad.reveal - 1)

            Canvas {
                id: plate
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: pad
                    function onLiveChanged() {
                        plate.requestPaint()
                    }
                    function onHotChanged() {
                        plate.requestPaint()
                    }
                    function onJoinOnLeftChanged() {
                        plate.requestPaint()
                    }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    const h = height
                    const cut = 8
                    const live = pad.live
                    const hot = pad.hot
                    const warn = Theme.warn

                    function slab(inset) {
                        const x = inset
                        const y = inset
                        const bw = w - inset * 2
                        const bh = h - inset * 2
                        const c = Math.max(2, cut - inset * 0.45)
                        ctx.beginPath()
                        ctx.moveTo(x + c, y)
                        ctx.lineTo(x + bw, y)
                        ctx.lineTo(x + bw, y + bh - c)
                        ctx.lineTo(x + bw - c, y + bh)
                        ctx.lineTo(x, y + bh)
                        ctx.lineTo(x, y + c)
                        ctx.closePath()
                    }

                    slab(0.6)
                    if (live) {
                        ctx.fillStyle = Qt.rgba(warn.r, warn.g, warn.b, 0.48)
                        ctx.globalAlpha = 1
                        ctx.fill()
                    } else {
                        const g = ctx.createLinearGradient(0, 0, w * 0.15, h)
                        g.addColorStop(0, "#121212")
                        g.addColorStop(0.55, "#0b0b0b")
                        g.addColorStop(1, "#050505")
                        ctx.globalAlpha = 0.9
                        ctx.fillStyle = g
                        ctx.fill()
                        ctx.globalAlpha = 1
                    }

                    ctx.strokeStyle = hot ? Theme.line : Theme.lineDim
                    ctx.lineWidth = 1.1
                    ctx.lineJoin = "miter"
                    ctx.stroke()

                    slab(3.4)
                    ctx.strokeStyle = Theme.lineFaint
                    ctx.lineWidth = 1
                    ctx.stroke()

                    const joinL = pad.joinOnLeft
                    ctx.strokeStyle = Theme.lineDim
                    ctx.lineWidth = 1.05
                    ctx.beginPath()
                    if (joinL) {
                        ctx.moveTo(1, h * 0.5)
                        ctx.lineTo(18, h * 0.5)
                    } else {
                        ctx.moveTo(w - 1, h * 0.5)
                        ctx.lineTo(w - 18, h * 0.5)
                    }
                    ctx.stroke()

                    ctx.fillStyle = Theme.lineDim
                    if (joinL)
                        ctx.fillRect(0, h * 0.5 - 3, 6, 6)
                    else
                        ctx.fillRect(w - 6, h * 0.5 - 3, 6, 6)

                    ctx.strokeStyle = Theme.lineFaint
                    ctx.lineWidth = 1
                    for (let i = 0; i < 3; i++) {
                        const yy = 8 + i * ((h - 16) / 2)
                        ctx.beginPath()
                        if (joinL) {
                            ctx.moveTo(w - 7, yy)
                            ctx.lineTo(w - 2, yy)
                        } else {
                            ctx.moveTo(2, yy)
                            ctx.lineTo(7, yy)
                        }
                        ctx.stroke()
                    }
                }
            }

            Rectangle {
                id: pip
                width: 8
                height: 8
                rotation: 45
                x: pad.joinOnLeft ? body.width - 22 : 14
                anchors.verticalCenter: parent.verticalCenter
                color: pad.live ? Theme.warn : "transparent"
                border.color: Theme.lineDim
                border.width: 1

                SequentialAnimation on opacity {
                    running: pad.live
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.35
                        duration: 720
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 720
                        easing.type: Easing.InOutSine
                    }
                    onRunningChanged: {
                        if (!running)
                            pip.opacity = 1
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: pad.label
                color: Theme.text
                font.family: Theme.fontHud
                font.pixelSize: 12
                font.letterSpacing: 1.4
                font.bold: true
                elide: Text.ElideRight
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pad.tapped()
            }
        }
    }

    onLiveChanged: {
        if (!pad.live)
            pip.opacity = 1
        plate.requestPaint()
    }
}
