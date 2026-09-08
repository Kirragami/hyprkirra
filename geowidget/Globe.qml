pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "svc"

Item {
    id: globe

    property var screen: null
    property var countries: []
    property real yaw: 0
    property real tilt: 0.32
    property real spin: 0.0048
    property bool primed: false
    property real settle: 0
    property bool paused: false
    property bool probePending: false
    property bool holdPause: false
    property bool exitLock: false
    property int probeGen: 0
    property int applyGen: 0
    property bool compact: false
    property real appear: 0
    property bool mapReady: false

    readonly property real dpr: {
        const s = globe.screen
        if (!s)
            return 1
        const v = Number(s.devicePixelRatio)
        return isFinite(v) && v > 0.5 ? v : 1
    }

    readonly property var hyprWs: {
        const mon = globe.screen ? Hyprland.monitorFor(globe.screen) : null
        return (mon && mon.activeWorkspace) || Hyprland.focusedWorkspace
    }

    readonly property int stackIndex: 0
    readonly property real pad: 10
    readonly property real padY: 46
    readonly property real dock: 204
    readonly property real textGap: 20
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real viewW: {
        const p = globe.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real moduleW: {
        const usable = globe.viewW - globe.pad * 2
        const gaps = globe.clusterGap * 2
        const raw = (usable - gaps) / 3
        const minW = globe.framePad * 2 + globe.dock + globe.textGap + 96
        return Math.max(minW, raw)
    }
    readonly property real plateW: Math.max(96, globe.moduleW - globe.framePad * 2 - globe.dock - globe.textGap)
    readonly property real stackPitch: globe.dock + globe.framePad * 2 + globe.clusterGap
    readonly property real viewH: {
        const p = globe.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real frameX: globe.pad + globe.moduleW + globe.clusterGap
    readonly property real frameY: globe.viewH - globe.dock - globe.padY - 3 * globe.stackPitch - globe.framePad
    readonly property real frameW: globe.moduleW * 2 + globe.clusterGap
    readonly property real frameH: {
        const ctrlY = globe.viewH - globe.dock - globe.padY - globe.framePad
        return Math.max(120, ctrlY - globe.clusterGap - globe.frameY)
    }
    readonly property real dockX: globe.pad + globe.moduleW + globe.clusterGap + globe.framePad
    readonly property real dockY: {
        const p = globe.parent
        if (!p)
            return 0
        return p.height - globe.dock - globe.padY - globe.stackIndex * globe.stackPitch
    }
    readonly property real hero: globe.dock
    readonly property real spawnX: globe.frameX + globe.frameW * 0.5 - globe.hero * 0.5
    readonly property real spawnY: globe.frameY + globe.frameH * 0.34 - globe.hero * 0.5

    width: globe.compact ? globe.dock : globe.hero
    height: width
    transformOrigin: Item.TopLeft
    scale: {
        if (globe.compact)
            return 1
        const h = Math.max(1, globe.hero)
        return 1 + (globe.dock / h - 1) * globe.settle
    }
    x: {
        const p = globe.parent
        if (!p)
            return 0
        return globe.spawnX * (1 - globe.settle) + globe.dockX * globe.settle
    }
    y: {
        const p = globe.parent
        if (!p)
            return 0
        return globe.spawnY * (1 - globe.settle) + globe.dockY * globe.settle
    }

    Component.onCompleted: globe.probeCover()
    onScreenChanged: globe.probeCover()

    function ingest(raw: string): void {
        let data
        try {
            data = JSON.parse(raw)
        } catch (e) {
            globe.countries = []
            return
        }
        const out = []
        for (let i = 0; i < data.length; i++) {
            const c = data[i]
            const rings = c.r || []
            const baked = []
            for (let r = 0; r < rings.length; r++) {
                const ring = rings[r]
                const pts = []
                for (let p = 0; p < ring.length; p++) {
                    const lon = ring[p][0]
                    const lat = ring[p][1]
                    const last = pts.length ? pts[pts.length - 1] : null
                    const tail = p === ring.length - 1
                    if (!tail && last) {
                        const dlon = lon - last.lon
                        const dlat = lat - last.lat
                        if (dlon * dlon + dlat * dlat < 0.08)
                            continue
                    }
                    pts.push({
                        lon: lon,
                        lat: lat
                    })
                }
                if (pts.length >= 4)
                    baked.push(pts)
            }
            out.push({
                a2: c.a2,
                n: c.n,
                r: baked
            })
        }
        globe.countries = out
        globe.faceHere()
        globe.probeCover()
        bake.requestPaint()
        if (!intro.running && globe.settle < 1)
            intro.start()
    }

    function pause(): void {
        if (globe.paused)
            return
        globe.paused = true
    }

    function resume(): void {
        if (!globe.paused)
            return
        globe.paused = false
    }

    function parseFullscreenFlag(data: string): int {
        const t = String(data || "").trim()
        if (!t.length)
            return -1
        const bits = t.split(",")
        const last = bits[bits.length - 1].trim()
        if (last === "0" || last === "false")
            return 0
        if (last === "1" || last === "true")
            return 1
        return -1
    }

    function onFullscreenFlag(on: bool): void {
        globe.probeGen += 1
        if (on) {
            globe.exitLock = false
            globe.holdPause = true
            globe.probePending = false
            globe.pause()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            return
        }
        globe.holdPause = false
        globe.exitLock = true
        globe.probePending = true
        globe.resume()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        coverKick.restart()
    }

    function isCoveredWindow(ipc: var): bool {
        if (!ipc)
            return false
        const fs = ipc.fullscreen
        if (fs === true || fs === 1 || fs === "1" || fs === 2 || fs === "2")
            return true
        const mode = Number(ipc.fullscreenClient)
        if (mode === 1 || mode === 2)
            return true
        const st = ipc.fullscreenstate || ipc.fullscreenState
        if (st && typeof st === "object") {
            if (Number(st.internal) > 0 || Number(st.client) > 0)
                return true
        }
        return false
    }

    function qsThinksCovered(): bool {
        const mon = globe.screen ? Hyprland.monitorFor(globe.screen) : null
        const ws = (mon && mon.activeWorkspace) || Hyprland.focusedWorkspace
        if (ws && ws.hasFullscreen)
            return true
        const t = Hyprland.activeToplevel
        if (t && globe.isCoveredWindow(t.lastIpcObject)) {
            if (!mon || !t.monitor || t.monitor.id === mon.id)
                return true
        }
        if (ws && ws.toplevels && ws.toplevels.values) {
            const list = ws.toplevels.values
            for (let i = 0; i < list.length; i++) {
                if (globe.isCoveredWindow(list[i] ? list[i].lastIpcObject : null))
                    return true
            }
        }
        return false
    }

    function syncCover(): void {
        if (globe.probePending)
            return
        if (globe.qsThinksCovered()) {
            if (!globe.exitLock)
                globe.pause()
            return
        }
        globe.exitLock = false
        globe.holdPause = false
        globe.resume()
    }

    function probeCover(): void {
        globe.probePending = true
        globe.probeGen += 1
        coverKick.restart()
    }

    function applyWorkspaceJson(raw: string): void {
        if (globe.applyGen !== globe.probeGen)
            return
        globe.probePending = false
        let list
        try {
            list = JSON.parse(raw)
        } catch (e) {
            globe.syncCover()
            return
        }
        if (!Array.isArray(list)) {
            globe.syncCover()
            return
        }
        const mon = globe.screen ? Hyprland.monitorFor(globe.screen) : null
        const monName = mon && mon.name ? String(mon.name) : ""
        const wsId = mon && mon.activeWorkspace ? Number(mon.activeWorkspace.id) : NaN
        let covered = false
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            if (!w || !w.hasfullscreen)
                continue
            if (monName.length && String(w.monitor) !== monName)
                continue
            if (isFinite(wsId) && Number(w.id) !== wsId)
                continue
            covered = true
            break
        }
        if (covered) {
            if (globe.exitLock) {
                globe.resume()
                return
            }
            globe.pause()
            return
        }
        globe.exitLock = false
        globe.holdPause = false
        globe.resume()
    }

    function faceHere(): void {
        if (Locate.hasFix && isFinite(Locate.lon)) {
            globe.yaw = -Locate.lon * Math.PI / 180
            globe.primed = true
            return
        }

        const iso = Locate.iso2
        if (!iso.length || !globe.countries.length)
            return

        let slon = 0
        let n = 0
        for (let i = 0; i < globe.countries.length; i++) {
            const c = globe.countries[i]
            if (c.a2 !== iso)
                continue
            const rings = c.r
            for (let r = 0; r < rings.length; r++) {
                const ring = rings[r]
                for (let p = 0; p < ring.length; p++) {
                    slon += ring[p].lon
                    n++
                }
            }
        }
        if (n > 0)
            globe.yaw = -slon / n * Math.PI / 180
        globe.primed = true
    }

    function lonJump(a: var, b: var): bool {
        let dlon = b.lon - a.lon
        if (dlon > 180)
            dlon -= 360
        else if (dlon < -180)
            dlon += 360
        return Math.abs(dlon) > 90
    }

    function ringHasJump(pts: var): bool {
        const n = pts.length
        for (let i = 0; i < n; i++) {
            if (globe.lonJump(pts[i], pts[(i + 1) % n]))
                return true
        }
        return false
    }

    function mapPt(p: var, w: real, h: real): var {
        return {
            x: (p.lon + 180) / 360 * w,
            y: (90 - p.lat) / 180 * h
        }
    }

    function addFlatRing(ctx: var, pts: var, w: real, h: real): void {
        const n = pts.length
        if (n < 3)
            return
        const a = globe.mapPt(pts[0], w, h)
        ctx.moveTo(a.x, a.y)
        for (let i = 1; i < n; i++) {
            const p = globe.mapPt(pts[i], w, h)
            ctx.lineTo(p.x, p.y)
        }
        ctx.closePath()
    }

    function paintMap(ctx: var): void {
        const w = bake.width
        const h = bake.height
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        if (w < 8 || h < 8)
            return

        const iso = Locate.iso2
        const list = globe.countries
        let home = null
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.lineWidth = Math.max(1.2, h * 0.0024)
        ctx.fillStyle = Theme.line
        ctx.strokeStyle = Theme.line

        for (let i = 0; i < list.length; i++) {
            const c = list[i]
            if (iso.length && c.a2 === iso) {
                home = c
                continue
            }
            const rings = c.r
            ctx.beginPath()
            for (let r = 0; r < rings.length; r++) {
                if (globe.ringHasJump(rings[r]))
                    continue
                globe.addFlatRing(ctx, rings[r], w, h)
            }
            ctx.globalAlpha = 0.42
            ctx.fill()
            ctx.globalAlpha = 0.92
            ctx.stroke()
        }

        if (home) {
            ctx.fillStyle = Theme.warn
            ctx.strokeStyle = Theme.warn
            ctx.beginPath()
            const rings = home.r
            for (let r = 0; r < rings.length; r++) {
                if (globe.ringHasJump(rings[r]))
                    continue
                globe.addFlatRing(ctx, rings[r], w, h)
            }
            ctx.globalAlpha = 0.82
            ctx.fill()
            ctx.globalAlpha = 1
            ctx.stroke()
        }
        ctx.globalAlpha = 1
    }

    FileView {
        path: `${Quickshell.shellDir}/countries.json`
        preload: true
        watchChanges: true
        onLoaded: globe.ingest(text())
    }

    Connections {
        target: Accent
        function onHexChanged(): void {
            bake.requestPaint()
        }
    }

    Connections {
        target: Locate
        function onIso2Changed(): void {
            globe.faceHere()
            bake.requestPaint()
        }
        function onHasFixChanged(): void {
            globe.faceHere()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            const n = event.name
            if (n === "fullscreen" || n === "fullscreenv2") {
                const flag = globe.parseFullscreenFlag(event.data)
                if (flag === 0 || flag === 1) {
                    globe.onFullscreenFlag(flag === 1)
                    return
                }
            }
            if (n === "fullscreen" || n === "fullscreenv2" || n === "workspace" || n === "workspacev2"
                    || n === "focusedmon" || n === "openwindow" || n === "closewindow"
                    || n === "activewindow" || n === "activewindowv2"
                    || n === "movewindow" || n === "movewindowv2"
                    || n === "fullscreenstate" || n === "fullscreenstatchange") {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
                globe.probeCover()
            }
        }
        function onFocusedWorkspaceChanged(): void { globe.probeCover() }
        function onActiveToplevelChanged(): void { globe.probeCover() }
        function onFocusedMonitorChanged(): void { globe.probeCover() }
    }

    Connections {
        target: globe.hyprWs
        function onHasFullscreenChanged(): void {
            if (!globe.probePending)
                globe.probeCover()
        }
    }

    Process {
        id: fsProbe
        command: ["hyprctl", "workspaces", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: globe.applyWorkspaceJson(text)
        }
        stderr: StdioCollector {}
        onExited: {
            if (exitCode !== 0 && globe.probePending) {
                globe.probePending = false
                globe.syncCover()
            }
        }
    }

    Timer {
        id: coverKick
        interval: 50
        repeat: false
        onTriggered: {
            globe.applyGen = globe.probeGen
            if (fsProbe.running)
                fsProbe.running = false
            fsProbe.running = true
        }
    }

    Canvas {
        id: bake
        width: 2048
        height: 1024
        x: -4096
        y: -4096
        visible: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onPaint: {
            globe.paintMap(getContext("2d"))
            globe.mapReady = true
            mapSync.restart()
        }
    }

    Timer {
        id: mapSync
        interval: 16
        repeat: false
        onTriggered: mapSrc.scheduleUpdate()
    }

    ShaderEffectSource {
        id: mapSrc
        sourceItem: bake
        hideSource: true
        live: false
        smooth: true
        mipmap: true
        wrapMode: ShaderEffectSource.Repeat
        textureMirroring: ShaderEffectSource.MirrorVertically
        textureSize: Qt.size(bake.width, bake.height)
    }

    GlitchReveal {
        id: fx
        anchors.fill: parent
        clip: false
        duration: 240
        intensity: 0.5
        slices: 5
        transformOrigin: Item.Center
        scale: 0.9 + 0.1 * globe.appear
        opacity: globe.appear > 0.01 ? Math.min(1, 0.35 + 0.65 * globe.appear) : 0

        ShaderEffect {
            id: orb
            anchors.fill: parent
            visible: globe.mapReady && !globe.paused
            blending: true
            antialiasing: true
            supportsAtlasTextures: false
            fragmentShader: Qt.resolvedUrl("globe.frag.qsb")
            property variant src: mapSrc
            property real yaw: globe.yaw
            property real tilt: globe.tilt
            property real px: 2.0 / Math.max(1, orb.width * globe.dpr * 2)
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(
                Math.max(1, Math.round(orb.width * globe.dpr * 2)),
                Math.max(1, Math.round(orb.height * globe.dpr * 2))
            )
        }
    }

    Timer {
        interval: 48
        running: globe.mapReady && globe.compact && !globe.paused
        repeat: true
        onTriggered: {
            globe.yaw += globe.spin
            if (globe.yaw > Math.PI * 2)
                globe.yaw -= Math.PI * 2
        }
    }

    SequentialAnimation {
        id: intro
        PauseAnimation {
            duration: 60
        }
        ScriptAction {
            script: fx.play(240)
        }
        NumberAnimation {
            target: globe
            property: "appear"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 80
        }
        NumberAnimation {
            target: globe
            property: "settle"
            to: 1
            duration: 420
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1, 0.3, 1]
        }
        PauseAnimation {
            duration: 32
        }
        ScriptAction {
            script: globe.compact = true
        }
    }
}
