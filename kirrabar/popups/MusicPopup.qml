import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 340
    paneHeight: 252

    property var player: null
    property bool playing: false
    property string title: ""
    property string artist: ""

    readonly property string art: pop.player ? (pop.player.trackArtUrl || "") : ""
    readonly property string album: pop.player ? (pop.player.trackAlbum || "") : ""
    readonly property string source: pop.player ? (pop.player.identity || "") : ""
    readonly property real pos: pop.player ? pop.player.position : 0
    readonly property real len: pop.player && pop.player.lengthSupported ? pop.player.length : 0
    readonly property real frac: pop.len > 0 ? Math.max(0, Math.min(1, pop.pos / pop.len)) : 0

    readonly property bool canPrev: pop.player && pop.player.canGoPrevious
    readonly property bool canToggle: {
        const p = pop.player
        if (!p)
            return false
        return p.canTogglePlaying || (pop.playing ? p.canPause : p.canPlay)
    }
    readonly property bool canNext: pop.player && pop.player.canGoNext

    function goPrev(): void {
        if (pop.canPrev)
            pop.player.previous()
    }

    function goToggle(): void {
        const p = pop.player
        if (!p)
            return
        if (p.canTogglePlaying)
            p.togglePlaying()
        else if (pop.playing && p.canPause)
            p.pause()
        else if (p.canPlay)
            p.play()
    }

    function goNext(): void {
        if (pop.canNext)
            pop.player.next()
    }

    function fmtPos(secs: real): string {
        if (!isFinite(secs) || secs < 0)
            return "0:00"
        const t = Math.floor(secs)
        const m = Math.floor(t / 60)
        const s = t % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 250
        running: pop.open && pop.playing
        repeat: true
        onTriggered: {
            if (pop.player)
                pop.player.positionChanged()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: 16

            GlitchText {
                value: pop.playing ? "AUD // LIVE" : "AUD // HOLD"
                settled: true
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 10
                font.letterSpacing: 1.8
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                text: pop.source.length ? pop.source.toUpperCase() : ""
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 9
                font.letterSpacing: 0.8
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Row {
            width: parent.width
            spacing: 12

            Item {
                width: 80
                height: 80

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bgRaised
                    border.color: Theme.lineDim
                    border.width: 1
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    anchors.margins: 2
                    source: pop.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 160
                    sourceSize.height: 160
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    cache: true
                    visible: cover.status === Image.Ready
                }

                Rectangle {
                    visible: cover.status !== Image.Ready
                    width: 10
                    height: 10
                    rotation: 45
                    color: pop.playing ? Theme.line : "transparent"
                    border.color: Theme.lineDim
                    border.width: 1
                    anchors.centerIn: parent
                }
            }

            Column {
                width: parent.width - 92
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: pop.title.length ? pop.title : "NO TRACK"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                Text {
                    width: parent.width
                    text: pop.artist.length ? pop.artist : "—"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: pop.album.length ? pop.album : "—"
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: pop.fmtPos(pop.pos) + "  /  " + (pop.len > 0 ? pop.fmtPos(pop.len) : "—")
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                }
            }
        }

        Item {
            id: seek
            width: parent.width
            height: 12
            readonly property int segs: 22
            readonly property int lit: Math.round(pop.frac * segs)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: seek.segs
                    Rectangle {
                        required property int index
                        width: (seek.width - (seek.segs - 1) * 2) / seek.segs
                        height: 10
                        color: index < seek.lit ? Theme.line : "transparent"
                        border.color: Theme.lineFaint
                        border.width: 1
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: pop.player && pop.player.canSeek && pop.len > 0
                onClicked: mouse => {
                    pop.player.position = (mouse.x / Math.max(1, width)) * pop.len
                }
            }
        }

        Row {
            id: transport
            width: parent.width
            spacing: 6

            component Glyph: Canvas {
                property string kind: "play"
                width: 18
                height: 18
                antialiasing: true
                onKindChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = Theme.line
                    const x0 = 2
                    const y0 = 2
                    const x1 = 16
                    const y1 = 16
                    const mid = 9

                    function tri(ax, ay, bx, by, cx, cy) {
                        ctx.beginPath()
                        ctx.moveTo(ax, ay)
                        ctx.lineTo(bx, by)
                        ctx.lineTo(cx, cy)
                        ctx.closePath()
                        ctx.fill()
                    }

                    if (kind === "pause") {
                        ctx.fillRect(x0, y0, 4, 14)
                        ctx.fillRect(12, y0, 4, 14)
                    } else if (kind === "play") {
                        tri(x0 + 1, y0, x1, mid, x0 + 1, y1)
                    } else if (kind === "prev") {
                        ctx.fillRect(x0, y0, 3, 14)
                        tri(x1, y0, 6, mid, x1, y1)
                    } else {
                        tri(x0, y0, 12, mid, x0, y1)
                        ctx.fillRect(13, y0, 3, 14)
                    }
                }
            }

            component Pad: Item {
                id: pad
                property string kind: "play"
                property string label: ""
                property bool armed: true
                signal tapped()

                width: (transport.width - 12) / 3
                height: 48
                opacity: armed ? 1 : 0.38

                Rectangle {
                    anchors.fill: parent
                    color: hit.containsMouse && pad.armed ? Theme.bgRaised : "transparent"
                    border.color: hit.containsMouse && pad.armed ? Theme.line : Theme.lineFaint
                    border.width: 1
                }

                Glyph {
                    kind: pad.kind
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: pad.label
                    color: Theme.textMute
                    font.family: Theme.fontHud
                    font.pixelSize: 8
                    font.letterSpacing: 1.4
                    font.bold: true
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    enabled: pad.armed
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pad.tapped()
                }
            }

            Pad {
                kind: "prev"
                label: "PREV"
                armed: pop.canPrev
                onTapped: pop.goPrev()
            }

            Pad {
                kind: pop.playing ? "pause" : "play"
                label: pop.playing ? "HOLD" : "PLAY"
                armed: pop.canToggle
                onTapped: pop.goToggle()
            }

            Pad {
                kind: "next"
                label: "NEXT"
                armed: pop.canNext
                onTapped: pop.goNext()
            }
        }
    }
}
