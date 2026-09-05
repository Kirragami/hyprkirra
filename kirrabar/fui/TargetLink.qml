import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "."

PanelWindow {
    id: link

    property Item originItem: null
    property var originWindow: null
    property bool locked: false

    anchors.left: true
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "kirrabar-link"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool hasWindow: false
    property real winX: 0
    property real winY: 0
    property real winW: 0
    property real winH: 0
    property int winMon: -1
    property string winAddr: ""
    property real progress: 0
    property bool ipcFullscreen: false
    property bool hasHold: false
    property real holdSx: 0
    property real holdSy: 0
    property real holdElbowY: 0
    property real holdTx: 0
    property real holdTy: 0
    property int boundWs: -1
    property real drawX: 0
    property real drawY: 0
    property real drawW: 0
    property real drawH: 0
    property bool drawReady: false
    property string stickEdge: ""
    property real joinAlong: 0.22
    property real curX: 0
    property real curY: 0
    property real lastAtX: 0
    property real lastAtY: 0
    property bool dragging: false
    property bool grabNextCursor: false
    property bool winFloating: false
    property real grabOffX: 0
    property real grabOffY: 0
    property bool glide: false
    property bool morphJoin: false
    property bool joinReady: false
    property real joinX: 0
    property real joinY: 0
    property real dropY: 0

    signal retracted()

    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    readonly property bool workspaceShift: Hyprland.focusedWorkspace !== null && link.boundWs !== -1 && link.boundWs !== link.focusedWs

    readonly property var monitor: Hyprland.monitorFor(link.screen)
    readonly property var toplevel: Hyprland.activeToplevel

    readonly property bool onThisScreen: {
        if (!link.hasWindow || !link.monitor)
            return false
        if (link.dragging)
            return true
        if (link.toplevel && link.toplevel.monitor && link.monitor.id === link.toplevel.monitor.id)
            return true
        if (link.winMon >= 0 && link.monitor.id === link.winMon)
            return true
        const mx = link.monitor.x
        const my = link.monitor.y
        const mw = link.monitor.width
        const mh = link.monitor.height
        return link.winX + link.winW > mx && link.winX < mx + mw && link.winY + link.winH > my && link.winY < my + mh
    }

    readonly property bool fullscreen: {
        const ws = Hyprland.focusedWorkspace
        if (ws && ws.hasFullscreen)
            return true
        return link.ipcFullscreen
    }

    readonly property bool armed: link.locked && link.hasWindow && link.onThisScreen && link.originItem !== null && !link.fullscreen && !link.workspaceShift

    onArmedChanged: {
        if (link.armed) {
            armOffDelay.stop()
            goneDelay.stop()
            retract.stop()
            link.boundWs = link.focusedWs
            if (link.progress < 0.99 && !deploy.running)
                deploy.start()
            return
        }
        if (link.workspaceShift) {
            armOffDelay.stop()
            goneDelay.stop()
            deploy.stop()
            link.glide = false
            link.morphJoin = false
            if (link.progress <= 0.001 || !link.hasHold)
                link.finishRetract()
            else if (!retract.running)
                retract.start()
            return
        }
        if (link.fullscreen) {
            armOffDelay.stop()
            goneDelay.stop()
            deploy.stop()
            retract.stop()
            link.progress = 0
            link.finishRetract()
            return
        }
        armOffDelay.restart()
    }

    Timer {
        id: armOffDelay
        interval: 100
        onTriggered: {
            if (link.armed || link.workspaceShift)
                return
            deploy.stop()
            if (link.fullscreen || link.progress <= 0.001 || !link.hasHold) {
                link.progress = 0
                link.finishRetract()
            } else if (!retract.running) {
                retract.start()
            }
        }
    }

    Timer {
        id: goneDelay
        interval: 80
        onTriggered: {
            if (link.toplevel)
                return
            link.hasWindow = false
        }
    }

    onFullscreenChanged: {
        if (link.fullscreen) {
            deploy.stop()
            retract.stop()
            link.progress = 0
            link.finishRetract()
        }
    }

    onFocusedWsChanged: {
        if (!Hyprland.focusedWorkspace)
            return
        if (link.progress <= 0.001)
            link.boundWs = link.focusedWs
    }

    function finishRetract(): void {
        link.retracted()
        if (Hyprland.focusedWorkspace)
            link.boundWs = link.focusedWs
    }

    onWinAddrChanged: {
        link.dragging = false
        link.grabNextCursor = false
        link.stickEdge = ""
    }

    onToplevelChanged: {
        link.dragging = false
        link.grabNextCursor = false
        link.syncGeom()
    }

    function sameAddr(a: string, b: string): bool {
        const na = (a || "").toLowerCase().replace(/^0x/, "")
        const nb = (b || "").toLowerCase().replace(/^0x/, "")
        return na.length > 0 && na === nb
    }

    function preferredEdge(left: real, top: real, lw: real, lh: real, sx: real, sy: real, canvasW: real): string {
        const right = left + lw
        const mid = left + lw * 0.5
        const over = sx >= left + 8 && sx <= right - 8
        const wide = lw >= canvasW * 0.72
        const screenMid = canvasW * 0.5
        if (wide && over && top > sy + 28)
            return "top"
        if (mid >= screenMid)
            return "left"
        return "top"
    }

    function commitJoin(tx: real, ty: real, ey: real, animate: bool): void {
        if (!isFinite(tx) || !isFinite(ty) || !isFinite(ey))
            return
        const useAnim = animate && link.joinReady && !link.dragging
        if (link.morphJoin !== useAnim)
            link.morphJoin = useAnim
        if (Math.abs(link.joinX - tx) > 0.4)
            link.joinX = tx
        if (Math.abs(link.joinY - ty) > 0.4)
            link.joinY = ty
        if (Math.abs(link.dropY - ey) > 0.4)
            link.dropY = ey
        link.joinReady = true
        link.holdTx = link.joinX
        link.holdTy = link.joinY
        link.holdElbowY = link.dropY
        link.hasHold = true
    }

    function setRect(nx: real, ny: real, nw: real, nh: real, mon: var, addr: string, fs: var, fsc: var): void {
        if (nw < 1 || nh < 1)
            return
        goneDelay.stop()
        const addrChanged = addr.length > 0 && !link.sameAddr(addr, link.winAddr)
        const jumped = link.drawReady && (Math.hypot(nx - link.winX, ny - link.winY) > 28
                || Math.abs(nw - link.winW) > 48 || Math.abs(nh - link.winH) > 48)
        if ((addrChanged || jumped) && link.progress > 0.85 && !link.workspaceShift && link.drawReady && !link.dragging) {
            link.glide = true
            glideOff.restart()
        } else if (link.workspaceShift) {
            link.glide = false
            link.morphJoin = false
        }
        if (!link.dragging && link.drawReady && (addrChanged || Math.abs(nw - link.winW) > 80))
            link.stickEdge = ""
        link.winX = nx
        link.winY = ny
        link.winW = nw
        link.winH = nh
        link.drawX = nx
        link.drawY = ny
        link.drawW = nw
        link.drawH = nh
        link.drawReady = true
        link.winMon = typeof mon === "number" ? mon : (link.toplevel && link.toplevel.monitor ? link.toplevel.monitor.id : -1)
        link.hasWindow = true
        link.ipcFullscreen = fs === true || fsc === true
                || (typeof fs === "number" && fs !== 0)
                || (typeof fsc === "number" && fsc !== 0)
        if (addr.length && addr !== link.winAddr)
            link.winAddr = addr
    }

    Timer {
        id: glideOff
        interval: 320
        onTriggered: {
            link.glide = false
            link.morphJoin = false
            canvas.requestPaint()
        }
    }

    Behavior on drawX {
        enabled: link.glide
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on drawY {
        enabled: link.glide
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on drawW {
        enabled: link.glide
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on drawH {
        enabled: link.glide
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on joinX {
        enabled: link.morphJoin
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on joinY {
        enabled: link.morphJoin
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on dropY {
        enabled: link.morphJoin
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    function beginGrab(): void {
        if (link.progress <= 0.2 || !link.drawReady)
            return
        link.grabNextCursor = true
        link.kickCursor()
    }

    function onCursor(cx: real, cy: real): void {
        if (!isFinite(cx) || !isFinite(cy))
            return
        if (link.grabNextCursor && link.drawReady) {
            link.grabOffX = cx - link.drawX
            link.grabOffY = cy - link.drawY
            link.dragging = true
            link.grabNextCursor = false
        }
        if (link.dragging) {
            link.drawX = cx - link.grabOffX
            link.drawY = cy - link.grabOffY
            link.winX = link.drawX
            link.winY = link.drawY
        }
        link.curX = cx
        link.curY = cy
    }

    function applyWindowJson(j: var): void {
        if (!j || !j.at || !j.size || j.size[0] < 1 || j.size[1] < 1)
            return
        const atX = j.at[0]
        const atY = j.at[1]
        const nw = j.size[0]
        const nh = j.size[1]
        const addr = j.address || ""
        const sameWin = link.sameAddr(addr, link.winAddr)
        const wasFloating = link.winFloating
        link.winFloating = j.floating === true || j.floating === 1
        if (sameWin && !wasFloating && link.winFloating)
            link.beginGrab()
        if (!sameWin) {
            link.dragging = false
            link.grabNextCursor = false
        }
        if (link.dragging) {
            link.drawW = nw
            link.drawH = nh
            link.winW = nw
            link.winH = nh
            const committed = Math.hypot(atX - link.drawX, atY - link.drawY) < 18
            const atJumped = Math.hypot(atX - link.lastAtX, atY - link.lastAtY) > 8
            if (committed || (atJumped && Math.hypot(atX - (link.curX - link.grabOffX), atY - (link.curY - link.grabOffY)) < 24)) {
                link.dragging = false
                link.grabNextCursor = false
                link.setRect(atX, atY, nw, nh, j.monitor, addr, j.fullscreen, j.fullscreenClient)
            }
            link.lastAtX = atX
            link.lastAtY = atY
            return
        }
        link.lastAtX = atX
        link.lastAtY = atY
        link.setRect(atX, atY, nw, nh, j.monitor, addr, j.fullscreen, j.fullscreenClient)
    }

    function syncGeom(): void {
        const t = link.toplevel
        if (!t) {
            if (!link.dragging)
                goneDelay.restart()
            return
        }
        goneDelay.stop()
        link.applyWindowJson(t.lastIpcObject)
    }

    function parseCursor(raw: string): void {
        const t = raw.trim()
        if (!t.length)
            return
        try {
            if (t.charAt(0) === "{") {
                const j = JSON.parse(t)
                link.onCursor(j.x, j.y)
                return
            }
        } catch (e) {
        }
        const p = t.split(",")
        if (p.length >= 2)
            link.onCursor(parseFloat(p[0]), parseFloat(p[1]))
    }

    function parseWindow(raw: string): void {
        const t = raw.trim()
        if (!t.length || t.charAt(0) !== "{")
            return
        try {
            link.applyWindowJson(JSON.parse(t))
        } catch (e) {
        }
    }

    function kickCursor(): void {
        if (!link.armed && !link.dragging)
            return
        cursorProbe.exec(["hyprctl", "-j", "cursorpos"])
    }

    function kickWindow(): void {
        if (!link.armed && !link.dragging)
            return
        if (winProbe.running)
            return
        winProbe.exec(["hyprctl", "-j", "activewindow"])
    }

    NumberAnimation {
        id: deploy
        target: link
        property: "progress"
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: retract
        target: link
        property: "progress"
        to: 0
        duration: 200
        easing.type: Easing.InOutCubic
        onFinished: {
            if (link.progress <= 0.001)
                link.finishRetract()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            const n = event.name
            if (n === "changefloatingmode") {
                const bits = (event.data || "").split(",")
                const addr = bits[0] || ""
                const floating = bits.length > 1 && (bits[1] === "1" || bits[1] === "true")
                if (addr.length && !link.sameAddr(addr, link.winAddr))
                    return
                if (!floating) {
                    link.dragging = false
                    link.grabNextCursor = false
                }
                return
            }
            if (n === "activewindow" || n === "activewindowv2" || n === "openwindow" || n === "closewindow"
                    || n === "fullscreen" || n === "workspace" || n === "workspacev2" || n === "focusedmon") {
                Hyprland.refreshToplevels()
                Qt.callLater(() => link.syncGeom())
            }
        }
    }

    Connections {
        target: link.toplevel
        function onLastIpcObjectChanged(): void {
            if (!link.dragging)
                link.syncGeom()
        }
        function onMonitorChanged(): void { link.syncGeom() }
        function onAddressChanged(): void { link.syncGeom() }
    }

    Process {
        id: cursorProbe
        stdout: StdioCollector {
            onStreamFinished: {
                link.parseCursor(text)
                if (link.dragging || link.grabNextCursor)
                    cursorKick.restart()
            }
        }
    }

    Timer {
        id: cursorKick
        interval: 8
        repeat: false
        onTriggered: link.kickCursor()
    }

    Timer {
        interval: 16
        running: link.dragging || link.grabNextCursor
        repeat: true
        onTriggered: {
            if (!cursorProbe.running && !cursorKick.running)
                link.kickCursor()
        }
    }

    Process {
        id: winProbe
        stdout: StdioCollector {
            onStreamFinished: {
                link.parseWindow(text)
                if (link.armed && link.progress > 0.15)
                    winKick.restart()
            }
        }
    }

    Timer {
        id: winKick
        interval: 32
        repeat: false
        onTriggered: link.kickWindow()
    }

    Timer {
        interval: 50
        running: link.armed && link.progress > 0.15
        repeat: true
        onTriggered: {
            if (!winProbe.running && !winKick.running)
                link.kickWindow()
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels()
        link.syncGeom()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: link
            function onProgressChanged(): void { canvas.requestPaint() }
            function onOriginItemChanged(): void { canvas.requestPaint() }
            function onDrawXChanged(): void { canvas.requestPaint() }
            function onDrawYChanged(): void { canvas.requestPaint() }
            function onDrawWChanged(): void { canvas.requestPaint() }
            function onDrawHChanged(): void { canvas.requestPaint() }
            function onJoinXChanged(): void { canvas.requestPaint() }
            function onJoinYChanged(): void { canvas.requestPaint() }
            function onDropYChanged(): void { canvas.requestPaint() }
            function onArmedChanged(): void { canvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (link.progress <= 0.001 || link.fullscreen || !link.monitor)
                return

            let sx
            let sy
            let tx
            let ty
            let elbowY
            const live = link.armed && link.originItem && link.hasWindow
            if (live) {
                const node = link.originItem
                const win = link.originWindow
                if (win && win.contentItem) {
                    const p = node.mapToItem(win.contentItem, node.width / 2, 0)
                    sx = p.x + win.margins.left
                    sy = p.y + win.margins.top
                } else {
                    const g = node.mapToGlobal(node.width / 2, 0)
                    const gp = canvas.mapFromGlobal(g.x, g.y)
                    sx = gp.x
                    sy = gp.y
                }
                if (!isFinite(sx) || !isFinite(sy))
                    return

                const nx = canvas.width / Math.max(1, link.monitor.width)
                const ny = canvas.height / Math.max(1, link.monitor.height)
                const pickX = link.dragging ? link.drawX : link.winX
                const pickY = link.dragging ? link.drawY : link.winY
                const pickW = link.dragging ? link.drawW : link.winW
                const pickH = link.dragging ? link.drawH : link.winH
                const left = (pickX - link.monitor.x) * nx
                const top = (pickY - link.monitor.y) * ny
                const lw = pickW * nx
                const lh = pickH * ny
                const right = left + lw
                const preferred = link.preferredEdge(left, top, lw, lh, sx, sy, canvas.width)
                const destMid = left + lw * 0.5
                const destTopX = Math.min(right - 24, Math.max(left + 24, sx + Math.max(48, (destMid - sx) * 0.45)))

                if (!link.dragging && link.stickEdge !== preferred)
                    link.stickEdge = ""

                if (!link.stickEdge || link.stickEdge.length === 0) {
                    link.stickEdge = preferred
                    if (link.stickEdge === "top")
                        link.joinAlong = lw > 1 ? Math.min(0.78, Math.max(0.22, (destTopX - left) / lw)) : 0.5
                    else
                        link.joinAlong = lh > 1 ? Math.min(0.86, Math.max(0.14, Math.min(lh * 0.26, 78) / lh)) : 0.22
                }

                const along = Math.min(0.86, Math.max(0.14, link.joinAlong))
                const edge = link.stickEdge
                if (edge === "top") {
                    tx = left + along * lw
                    ty = top
                } else if (edge === "left") {
                    tx = left
                    ty = top + along * lh
                } else {
                    tx = right
                    ty = top + along * lh
                }

                const room = ty - sy
                let drop
                if (edge === "top")
                    drop = room > 64 ? Math.min(room * 0.55, Math.max(48, room - 36)) : Math.max(14, room * 0.4)
                else
                    drop = room > 56 ? Math.min(room * 0.72, 128) : Math.max(16, room * 0.45)
                elbowY = sy + Math.max(8, drop)
                const animateJoin = link.glide && !link.dragging
                const wantX = tx
                const wantY = ty
                const wantE = elbowY
                if (link.joinReady) {
                    tx = link.joinX
                    ty = link.joinY
                    elbowY = link.dropY
                }
                link.holdSx = sx
                link.holdSy = sy
                Qt.callLater(() => link.commitJoin(wantX, wantY, wantE, animateJoin))
            } else if (link.hasHold) {
                sx = link.holdSx
                sy = link.holdSy
                elbowY = link.holdElbowY
                tx = link.holdTx
                ty = link.holdTy
            } else {
                return
            }

            const pts = [
                { x: sx, y: sy },
                { x: sx, y: elbowY },
                { x: tx, y: ty }
            ]
            HudStroke.draw(ctx, pts, link.progress, Theme.line)
        }
    }
}
