pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: track
    property bool settled: true
    property bool selected: false
    readonly property bool compact: track.width <= 318
    property var player: null
    readonly property alias artFace: coverBox
    signal clicked()

    readonly property bool playing: {
        const p = track.player
        if (!p)
            return false
        return p.playbackState === MprisPlaybackState.Playing
    }
    readonly property bool live: track.player !== null
    readonly property string title: track.player ? (track.player.trackTitle || "UNTITLED") : ""
    readonly property string artist: track.player ? (track.player.trackArtist || track.player.trackAlbumArtist || "") : ""
    readonly property string art: track.player ? (track.player.trackArtUrl || "") : ""
    readonly property bool spotify: track.playerName(track.player).indexOf("spotify") !== -1
    property bool spotifyOut: false
    property bool remoteReady: false
    property bool remoteLatch: false
    property int pwGen: 0
    property string notedDevice: ""
    property string fetchedDevice: ""
    readonly property bool away: track.spotify && !track.spotifyOut && (track.playing || track.remoteLatch)
    readonly property bool remote: track.away && track.remoteReady
    readonly property bool wide: !track.compact && track.width > 318
    readonly property int wantWidth: 12 + 1 + 10 + 36 + 10 + 168 + 8 + 28 + 4
    readonly property string deviceName: {
        const fetched = (track.fetchedDevice || "").trim()
        if (fetched.length)
            return fetched.toUpperCase()
        const meta = track.deviceField(track.player ? track.player.metadata : null, "name")
        if (meta.length)
            return meta
        const note = (track.notedDevice || "").trim()
        if (note.length)
            return note.toUpperCase()
        return ""
    }
    readonly property string deviceLabel: track.deviceName.length ? ("ON " + track.deviceName) : "ON REMOTE"

    implicitWidth: 0
    implicitHeight: 44
    clip: !track.selected
    opacity: track.live ? 1 : 0
    visible: width > 2

    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }

    function playerName(p: var): string {
        if (!p)
            return ""
        return ((p.identity || "") + " " + (p.dbusName || "") + " " + (p.desktopEntry || "")).toLowerCase()
    }

    function metaText(md: var, key: string): string {
        if (!md || !key)
            return ""
        const v = md[key]
        if (v === undefined || v === null)
            return ""
        if (typeof v === "object" && v !== null && v.length !== undefined) {
            const parts = []
            for (let i = 0; i < v.length; i++)
                parts.push(String(v[i] || ""))
            return parts.join(" ").trim()
        }
        return String(v).trim()
    }

    function parsePlayingOn(text: string): string {
        const t = (text || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
        if (!t.length)
            return ""
        const m = t.match(/playing on\s+(.+)/i) || t.match(/listening on\s+(.+)/i)
        if (!m)
            return ""
        return m[1].replace(/[.!]+$/, "").trim()
    }

    function harvestNotes(): void {
        const list = Notifs.items
        if (!list)
            return
        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (!n)
                continue
            const app = String(n.appName || "")
            const blob = app + " " + String(n.summary || "") + " " + String(n.body || "")
            if (!/spotif/i.test(blob) && !/spotif/i.test(app))
                continue
            const name = track.parsePlayingOn(n.body || "") || track.parsePlayingOn(n.summary || "")
            if (name.length) {
                track.notedDevice = name
                return
            }
        }
    }

    function deviceField(md: var, kind: string): string {
        if (!md)
            return ""
        const names = kind === "type"
            ? ["xesam:deviceType", "spotify:deviceType", "deviceType", "device_type"]
            : ["xesam:device", "xesam:deviceName", "spotify:device", "spotify:deviceName", "device", "deviceName", "device_name"]
        for (let i = 0; i < names.length; i++) {
            const s = track.metaText(md, names[i])
            if (s.length)
                return s.toUpperCase()
        }
        let keys = []
        try {
            keys = Object.keys(md)
        } catch (e) {
            keys = []
        }
        const re = kind === "type" ? /device[_ ]?type/i : /(^|:)device(name)?$/i
        for (let i = 0; i < keys.length; i++) {
            if (!re.test(keys[i]))
                continue
            const s = track.metaText(md, keys[i])
            if (s.length)
                return s.toUpperCase()
        }
        return ""
    }

    function nodeBlob(node: var): string {
        if (!node)
            return ""
        const p = node.ready ? (node.properties || {}) : {}
        return [
            p["application.name"],
            p["application.process.binary"],
            p["application.id"],
            p["node.name"],
            node.nickname,
            node.description,
            node.name
        ].map(v => (v || "").toString().toLowerCase()).join(" ")
    }

    function isSpotifyOut(node: var): bool {
        if (!node || !node.ready || !node.isStream)
            return false
        const cls = String((node.properties || {})["media.class"] || "")
        if (cls.indexOf("Stream/Output/Audio") === -1)
            return false
        return track.nodeBlob(node).indexOf("spotify") !== -1
    }

    function scanOut(): void {
        let hit = false
        if (track.spotify && Pipewire.nodes) {
            const list = Pipewire.nodes.values
            for (let i = 0; i < list.length; i++) {
                if (track.isSpotifyOut(list[i])) {
                    hit = true
                    break
                }
            }
        }
        track.spotifyOut = hit
    }

    function syncRemote(): void {
        if (track.spotify && track.playing && !track.spotifyOut) {
            track.harvestNotes()
            remoteArm.restart()
            track.kickDevice()
        } else if (!track.spotify || track.spotifyOut) {
            remoteArm.stop()
            track.remoteReady = false
            track.remoteLatch = false
            if (!track.spotify) {
                track.notedDevice = ""
                track.fetchedDevice = ""
            }
        }
    }

    function readDevice(raw: string): void {
        const line = (raw || "").trim().split("\n")[0] || ""
        if (!line.length)
            return
        const name = line.split("\t")[0].trim()
        if (name.length)
            track.fetchedDevice = name
    }

    function kickDevice(): void {
        if (!track.away || deviceProbe.running)
            return
        deviceProbe.running = true
    }

    function isBrowser(name: string): bool {
        return /chrom|firefox|brave|vivaldi|msedge|microsoft-edge|opera|floorp|librewolf/.test(name)
    }

    function isCallSession(p: var): bool {
        if (!p)
            return false
        const name = track.playerName(p)
        const title = ((p.trackTitle || "") + " " + (p.trackArtist || "") + " " + (p.trackAlbum || "")).toLowerCase()
        if (/teams|google meet|zoom|discord|skype|webex|jitsi|slack call|voice connected/.test(title))
            return true
        if (/teams|zoom|discord|skype/.test(name) && !track.isBrowser(name))
            return true
        if (CallWatch.connected && track.isBrowser(name))
            return true
        if (CallWatch.connected && CallWatch.appName.length) {
            const app = CallWatch.appName.toLowerCase()
            if (app.length > 2 && name.indexOf(app) !== -1)
                return true
        }
        return false
    }

    function score(p: var): int {
        if (!p)
            return -1
        if (track.isCallSession(p))
            return -1
        const playing = p.isPlaying === true || p.playbackState === MprisPlaybackState.Playing
        const paused = !playing && p.playbackState === MprisPlaybackState.Paused
        if (!playing && !paused)
            return -1
        const title = (p.trackTitle || "").trim()
        const artist = (p.trackArtist || "").trim()
        if (!playing && !title && !artist)
            return -1
        const name = track.playerName(p)
        let s = playing ? 100 : 40
        if (title.length)
            s += 10
        if (name.indexOf("spotify") !== -1)
            s += 6
        else if (name.indexOf("youtube") !== -1)
            s += 4
        else if (track.isBrowser(name))
            s += 2
        return s
    }

    function resync(): void {
        const list = Mpris.players.values
        let best = null
        let bestScore = -1
        for (let i = 0; i < list.length; i++) {
            const sc = track.score(list[i])
            if (sc > bestScore) {
                bestScore = sc
                best = list[i]
            }
        }
        if (bestScore < 0)
            best = null
        if (track.player !== best)
            track.player = best
    }

    Repeater {
        model: Mpris.players
        Item {
            required property var modelData
            width: 0
            height: 0
            Connections {
                target: modelData
                function onIsPlayingChanged(): void { track.resync() }
                function onPlaybackStateChanged(): void { track.resync() }
                function onTrackTitleChanged(): void { track.resync() }
                function onTrackArtistChanged(): void { track.resync() }
                function onTrackArtUrlChanged(): void { track.resync() }
            }
            Component.onCompleted: track.resync()
            Component.onDestruction: Qt.callLater(track.resync)
        }
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost(object, index): void { track.resync() }
        function onObjectRemovedPost(object, index): void { track.resync() }
    }

    Connections {
        target: Notifs
        function onItemsChanged(): void {
            if (track.spotify)
                track.harvestNotes()
        }
    }

    Connections {
        target: CallWatch
        function onConnectedChanged(): void { track.resync() }
        function onAppNameChanged(): void { track.resync() }
    }

    Component.onCompleted: {
        track.resync()
        track.scanOut()
        track.syncRemote()
    }

    onAwayChanged: track.syncRemote()
    onSpotifyOutChanged: track.syncRemote()
    onSpotifyChanged: track.scanOut()
    onPlayingChanged: track.scanOut()

    Timer {
        id: remoteArm
        interval: 220
        onTriggered: {
            if (track.spotify && !track.spotifyOut) {
                track.remoteReady = true
                track.remoteLatch = true
            }
        }
    }

    Timer {
        interval: 350
        running: track.spotify
        repeat: true
        onTriggered: {
            track.scanOut()
            if (track.away)
                track.harvestNotes()
        }
    }

    Process {
        id: deviceProbe
        command: ["python3", "-u", Quickshell.shellPath("fui/spotify_device.py")]
        running: false
        stdout: StdioCollector {
            onStreamFinished: track.readDevice(text)
        }
        stderr: StdioCollector {}
        onExited: {
            if (track.away)
                deviceRetry.restart()
        }
    }

    Timer {
        id: deviceRetry
        interval: 6000
        onTriggered: track.kickDevice()
    }

    Timer {
        interval: 8000
        running: track.away
        repeat: true
        onTriggered: track.kickDevice()
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index): void {
            track.pwGen++
            track.scanOut()
        }
        function onObjectRemovedPost(object, index): void {
            track.pwGen++
            track.scanOut()
        }
    }

    PwObjectTracker {
        objects: {
            const _ = track.pwGen
            const out = []
            const list = Pipewire.nodes.values
            for (let i = 0; i < list.length; i++) {
                const n = list[i]
                if (n && n.isStream)
                    out.push(n)
            }
            return out
        }
    }

    Binding {
        target: Spectrum
        property: "active"
        value: track.live && track.playing && track.wide && !track.away
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4

        Rectangle {
            id: rule
            width: 1
            height: 28
            color: Theme.lineFaint
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        HudPick {
            id: coverBox
            width: 36
            height: 36
            z: track.selected ? 2 : 0
            lockPad: 6
            selected: track.selected
            anchors.left: rule.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                color: Theme.bgRaised
                border.color: track.selected ? Theme.line : Theme.lineDim
                border.width: 1
            }

            Image {
                id: cover
                anchors.fill: parent
                anchors.margins: 2
                source: track.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 64
                sourceSize.height: 64
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                visible: cover.status === Image.Ready
            }

            Rectangle {
                visible: cover.status !== Image.Ready
                width: 8
                height: 8
                rotation: 45
                color: track.playing ? Theme.line : "transparent"
                border.color: Theme.lineDim
                border.width: 1
                anchors.centerIn: parent
            }

            Canvas {
                id: lockTicks
                anchors.fill: parent
                visible: track.remote
                opacity: 0.55 + 0.45 * ping.beat
                antialiasing: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    const h = height
                    const t = 5
                    const i = 2.5
                    ctx.strokeStyle = Theme.line
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(i, i + t)
                    ctx.lineTo(i, i)
                    ctx.lineTo(i + t, i)
                    ctx.moveTo(w - i - t, i)
                    ctx.lineTo(w - i, i)
                    ctx.lineTo(w - i, i + t)
                    ctx.moveTo(w - i, h - i - t)
                    ctx.lineTo(w - i, h - i)
                    ctx.lineTo(w - i - t, h - i)
                    ctx.moveTo(i + t, h - i)
                    ctx.lineTo(i, h - i)
                    ctx.lineTo(i, h - i - t)
                    ctx.stroke()
                }
            }
        }

        Column {
            id: meta
            spacing: 1
            width: Math.min(track.remote || track.compact ? 168 : 220, Math.max(72, track.width - 80 - (track.remote ? 36 : 0)))
            anchors.left: coverBox.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            GlitchText {
                value: track.away ? (track.playing ? "AUD // LINK" : "AUD // HOLD") : (track.playing ? "AUD // LIVE" : "AUD // HOLD")
                settled: track.settled && track.live
                glitchOnChange: true
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 9
                font.letterSpacing: 1.4
                font.bold: true
            }

            GlitchText {
                width: parent.width
                value: track.title
                settled: track.settled && track.live
                glitchOnChange: true
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }

            GlitchText {
                width: parent.width
                value: track.remote ? track.deviceLabel : (track.artist.length ? track.artist : "—")
                settled: track.settled && track.live
                glitchOnChange: true
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Canvas {
            id: ping
            visible: width > 2
            width: track.remote ? 28 : 0
            height: 36
            anchors.left: meta.right
            anchors.leftMargin: track.remote ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            antialiasing: true
            opacity: track.remote ? 1 : 0
            property real t: 0
            readonly property real beat: 0.5 + 0.5 * Math.sin(ping.t * 2.4)

            Behavior on width {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onTChanged: requestPaint()
            onVisibleChanged: requestPaint()

            Timer {
                interval: 16
                running: ping.visible
                repeat: true
                onTriggered: ping.t += 0.016
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width
                const h = height
                if (w < 8 || h < 8)
                    return

                const cx = w * 0.5
                const cy = h * 0.5
                const maxR = Math.min(w, h) * 0.46
                const t = ping.t

                ctx.strokeStyle = Theme.lineFaint
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.45
                ctx.beginPath()
                ctx.arc(cx, cy, maxR, 0, Math.PI * 2)
                ctx.stroke()

                for (let i = 0; i < 3; i++) {
                    const u = (t * 0.42 + i / 3) % 1
                    const r = 3 + u * (maxR - 3)
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.globalAlpha = (1 - u) * 0.55
                    ctx.strokeStyle = Theme.line
                    ctx.stroke()
                }

                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(t * 1.15)
                ctx.globalAlpha = 0.55
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(maxR * 0.92, 0)
                ctx.strokeStyle = Theme.line
                ctx.stroke()
                ctx.restore()

                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(45 * Math.PI / 180)
                ctx.globalAlpha = 0.35 + ping.beat * 0.65
                ctx.fillStyle = Theme.line
                ctx.fillRect(-3, -3, 6, 6)
                ctx.restore()
                ctx.globalAlpha = 1
            }
        }

        Canvas {
            id: wave
            visible: track.wide && !track.away
            anchors.left: meta.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 28

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: Spectrum
                function onLevelsChanged(): void { wave.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width
                const h = height
                if (w < 8 || h < 4)
                    return

                const levels = Spectrum.levels
                const n = levels && levels.length ? levels.length : 0

                ctx.strokeStyle = Theme.lineFaint
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.35
                ctx.beginPath()
                ctx.moveTo(0, h - 0.5)
                ctx.lineTo(w, h - 0.5)
                ctx.stroke()

                if (!n) {
                    ctx.globalAlpha = 1
                    return
                }

                const step = w / n
                const bw = Math.max(1, Math.min(2, step * 0.35))
                ctx.beginPath()
                for (let i = 0; i < n; i++) {
                    const v = Math.max(0, Math.min(1, Number(levels[i]) || 0)) * 0.96
                    const x = (i + 0.5) * step
                    const y = h - 1 - v * (h - 3)
                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.strokeStyle = Theme.line
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.5
                ctx.stroke()

                ctx.fillStyle = Theme.line
                for (let i = 0; i < n; i++) {
                    const v = Math.max(0, Math.min(1, Number(levels[i]) || 0)) * 0.96
                    const x = (i + 0.5) * step
                    const bh = Math.max(1, v * (h - 3))
                    ctx.globalAlpha = 0.16 + v * 0.28
                    ctx.fillRect(x - bw / 2, h - bh, bw, bh)
                }
                ctx.globalAlpha = 1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: track.live
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            const p = track.player
            if (!p)
                return
            if (mouse.button === Qt.RightButton) {
                if (p.canRaise)
                    p.raise()
                return
            }
            track.clicked()
        }
    }
}
