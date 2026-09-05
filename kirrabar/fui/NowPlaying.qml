pragma ComponentBehavior: Bound

import Quickshell.Services.Mpris
import QtQuick

Item {
    id: track
    property bool settled: true
    property bool selected: false
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

    function score(p: var): int {
        if (!p)
            return -1
        const playing = p.isPlaying === true || p.playbackState === MprisPlaybackState.Playing
        const paused = !playing && p.playbackState === MprisPlaybackState.Paused
        if (!playing && !paused)
            return -1
        const title = (p.trackTitle || "").trim()
        const artist = (p.trackArtist || "").trim()
        if (!playing && !title && !artist)
            return -1
        const name = ((p.identity || "") + " " + (p.dbusName || "") + " " + (p.desktopEntry || "")).toLowerCase()
        let s = playing ? 100 : 40
        if (title.length)
            s += 10
        if (name.indexOf("spotify") !== -1)
            s += 6
        else if (name.indexOf("firefox") !== -1 || name.indexOf("chrom") !== -1 || name.indexOf("brave") !== -1 || name.indexOf("youtube") !== -1)
            s += 4
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

    Component.onCompleted: track.resync()

    Binding {
        target: Spectrum
        property: "active"
        value: track.live && track.playing
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
        }

        Column {
            id: meta
            spacing: 1
            width: 220
            anchors.left: coverBox.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            GlitchText {
                value: track.playing ? "AUD // LIVE" : "AUD // HOLD"
                settled: track.settled && track.live
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

            Text {
                width: parent.width
                text: track.artist.length ? track.artist : "—"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Canvas {
            id: wave
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
