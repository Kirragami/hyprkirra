import Quickshell
import Quickshell.Wayland
import QtQuick
import "."

PanelWindow {
    id: lock

    property Item faceItem: null
    property var originWindow: null
    property Item joinItem: null
    property bool locked: false
    property real gap: 120
    property real offsetX: -88
    property string ns: "kirrabar-lock"

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    visible: lock.locked || lock.form > 0.002 || lock.progress > 0.002

    WlrLayershell.namespace: lock.ns
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property real progress: 0
    property real form: 0
    property real ringOp: 0
    property bool hasHold: false
    property real holdCx: 0
    property real holdCy: 0
    property real holdR: 0
    property real holdRi: 0
    property real holdSx: 0
    property real holdSy: 0
    property real holdTx: 0
    property real holdTy: 0

    onLockedChanged: {
        if (lock.locked) {
            retract.stop()
            formOut.stop()
            fadeRings.stop()
            lock.form = 0
            lock.progress = 0
            lock.ringOp = 1
            formIn.restart()
            deploy.restart()
        } else {
            deploy.stop()
            formIn.stop()
            const needRetract = lock.progress > 0.001
            const needUnform = lock.form > 0.001
            if (needRetract)
                retract.restart()
            if (needUnform)
                formOut.restart()
            if (!needRetract && !needUnform) {
                lock.progress = 0
                lock.form = 0
                fadeRings.restart()
            }
        }
    }

    onFaceItemChanged: {
        if (lock.locked && lock.faceItem) {
            retract.stop()
            formOut.stop()
            formIn.stop()
            deploy.stop()
            fadeRings.stop()
            lock.form = 0
            lock.progress = 0
            lock.ringOp = 1
            lock.syncFace()
            formIn.restart()
            deploy.restart()
        } else {
            lock.syncFace()
        }
        canvas.requestPaint()
    }

    function syncFace(): void {
        const face = lock.faceItem
        const win = lock.originWindow
        if (!(lock.locked && face && win && win.contentItem))
            return
        const mid = face.mapToItem(win.contentItem, face.width / 2, face.height / 2)
        const nx = mid.x + win.margins.left
        const ny = mid.y + win.margins.top
        if (!isFinite(nx) || !isFinite(ny) || face.lockR <= 1)
            return
        lock.holdCx = nx
        lock.holdCy = ny
        lock.holdR = face.lockR
        lock.holdRi = face.lockInner
        lock.holdSx = nx
        lock.holdSy = ny + face.lockR
        lock.holdTx = nx + lock.offsetX
        lock.holdTy = lock.holdSy + lock.gap
        const join = lock.joinItem
        if (join) {
            const g = join.mapToGlobal(join.width / 2, 0)
            const p = canvas.mapFromGlobal(g.x, g.y)
            if (isFinite(p.x) && isFinite(p.y) && p.y > lock.holdSy + 8) {
                lock.holdTx = p.x
                lock.holdTy = p.y
            }
        }
        lock.hasHold = true
    }

    NumberAnimation {
        id: formIn
        target: lock
        property: "form"
        from: 0
        to: 1
        duration: Theme.lockFormMs
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: formOut
        target: lock
        property: "form"
        to: 0
        duration: 160
        easing.type: Easing.InCubic
        onStopped: {
            if (!lock.locked) {
                lock.form = 0
                if (lock.progress <= 0.001) {
                    lock.ringOp = 0
                    lock.hasHold = false
                }
            }
        }
    }

    NumberAnimation {
        id: deploy
        target: lock
        property: "progress"
        from: 0
        to: 1
        duration: Theme.lockLineMs
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: retract
        target: lock
        property: "progress"
        to: 0
        duration: 160
        easing.type: Easing.InCubic
        onStopped: {
            if (!lock.locked) {
                lock.progress = 0
                if (lock.form <= 0.001) {
                    lock.ringOp = 0
                    lock.hasHold = false
                }
            }
            canvas.requestPaint()
        }
    }

    NumberAnimation {
        id: fadeRings
        target: lock
        property: "ringOp"
        to: 0
        duration: 160
        onStopped: {
            if (!lock.locked && lock.progress <= 0.001)
                lock.hasHold = false
        }
    }

    Timer {
        interval: 16
        running: lock.visible
        repeat: true
        onTriggered: {
            lock.syncFace()
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: lock
            function onProgressChanged(): void { canvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (lock.progress <= 0.001 || !lock.hasHold)
                return
            const sx = lock.holdSx
            const sy = lock.holdSy
            const tx = lock.holdTx
            const ty = lock.holdTy
            if (!isFinite(sx) || !isFinite(sy) || !isFinite(tx) || !isFinite(ty))
                return
            const fall = Math.max(28, Math.min(56, (ty - sy) * 0.28))
            const rest = Math.max(0, ty - sy - fall)
            HudStroke.draw(ctx, [
                { x: sx, y: sy },
                { x: sx, y: sy + fall },
                { x: tx, y: sy + fall + rest * 0.35 },
                { x: tx, y: ty }
            ], lock.progress, Theme.line)
        }
    }

    Item {
        id: rings
        visible: lock.hasHold && lock.holdR > 1 && (lock.locked || lock.form > 0.002)
        x: lock.holdCx
        y: lock.holdCy
        opacity: lock.ringOp

        HudRing {
            anchors.centerIn: parent
            width: lock.holdR * 2 + 6
            height: width
            radius: lock.holdR
            gapDeg: 72
            startDeg: -50
            weight: 1.4
            form: lock.form
            spinMs: Theme.ringSpinOutMs
        }

        HudRing {
            anchors.centerIn: parent
            width: lock.holdRi * 2 + 6
            height: width
            radius: lock.holdRi
            gapDeg: 88
            startDeg: 110
            weight: 1.2
            form: lock.form
            reverse: true
            spinClockwise: false
            spinMs: Theme.ringSpinInMs
            opacity: 0.9
        }
    }
}
