import QtQuick

Item {
    id: chip

    property bool settled: true
    property bool dying: false
    property real drain: 1
    property real fade: 1
    property real spread: 1
    property real textOn: 1
    property real bay: 1
    property real trace: 1
    property bool waveOn: true
    readonly property bool slotOpen: CallWatch.connected || chip.dying
    property color fill: chip.dying ? Theme.callDead : Theme.callLive

    readonly property int slabW: 340
    readonly property int slabH: 48
    property int maxWidth: 340
    readonly property int slabNow: Math.min(chip.slabW, chip.maxWidth)
    readonly property int labelW: Math.ceil(tagFit.width) + 22
    readonly property int bayW: Math.max(0, chip.slabNow - chip.labelW)

    width: chip.slotOpen ? chip.labelW + chip.bayW * chip.bay : 0
    implicitHeight: chip.slabH
    height: chip.slabH
    clip: !fx.glitching
    visible: width > 1
    opacity: chip.slotOpen ? Math.max(0, chip.fade) : 0

    Behavior on fill {
        ColorAnimation {
            duration: 180
        }
    }

    TextMetrics {
        id: tagFit
        font.family: Theme.fontHud
        font.pixelSize: 14
        font.letterSpacing: 0.6
        font.bold: true
        text: "CALL CONNECTED"
    }

    function armIntro(): void {
        hangup.stop()
        chip.dying = false
        chip.drain = 1
        chip.fade = 1
        chip.spread = 0
        chip.textOn = 0
        chip.bay = 0
        chip.trace = 0
        chip.waveOn = false
        intro.restart()
    }

    function armHangup(): void {
        intro.stop()
        chip.spread = 1
        chip.textOn = 1
        chip.bay = 1
        chip.trace = 1
        chip.waveOn = true
        chip.drain = 1
        chip.fade = 1
        chip.dying = true
        fx.play(1200)
        hangup.restart()
    }

    Connections {
        target: CallWatch
        function onConnectedChanged(): void {
            if (CallWatch.connected)
                chip.armIntro()
            else if (chip.visible || chip.bay > 0.05 || chip.spread > 0.05)
                chip.armHangup()
        }
    }

    SequentialAnimation {
        id: intro
        NumberAnimation {
            target: chip
            property: "spread"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: tag.kick(100)
        }
        NumberAnimation {
            target: chip
            property: "textOn"
            to: 1
            duration: 90
        }
        PauseAnimation {
            duration: 50
        }
        NumberAnimation {
            target: chip
            property: "bay"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 30
        }
        NumberAnimation {
            target: chip
            property: "trace"
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 30
        }
        ScriptAction {
            script: chip.waveOn = true
        }
    }

    SequentialAnimation {
        id: hangup
        ScriptAction {
            script: tag.kick(90)
        }
        PauseAnimation {
            duration: 520
        }
        NumberAnimation {
            target: chip
            property: "drain"
            to: 0
            duration: 70
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: chip.waveOn = false
        }
        NumberAnimation {
            target: chip
            property: "trace"
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: chip
            property: "bay"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: tag.kick(80)
        }
        NumberAnimation {
            target: chip
            property: "textOn"
            to: 0
            duration: 70
        }
        NumberAnimation {
            target: chip
            property: "spread"
            to: 0
            duration: 140
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: chip
            property: "fade"
            to: 0
            duration: 70
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                chip.dying = false
                chip.drain = 1
                chip.fade = 1
                chip.spread = 1
                chip.textOn = 1
                chip.bay = 1
                chip.trace = 1
                chip.waveOn = true
            }
        }
    }

    GlitchReveal {
        id: fx
        anchors.fill: parent
        duration: 1200
        intensity: 0.82
        slices: 6

        Item {
            anchors.fill: parent

            Item {
                id: labelPad
                width: chip.labelW
                height: parent.height
                clip: true

                Rectangle {
                    width: parent.width
                    height: 2 + Math.max(0, parent.height - 2) * chip.spread
                    anchors.verticalCenter: parent.verticalCenter
                    color: chip.fill
                }

                Canvas {
                    id: ticks
                    anchors.fill: parent
                    opacity: chip.textOn
                    antialiasing: true
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width
                        const h = height
                        const tick = 5
                        const inset = 3.2
                        ctx.strokeStyle = "#f3f3f3"
                        ctx.lineWidth = 1
                        ctx.globalAlpha = 0.5
                        ctx.beginPath()
                        ctx.moveTo(inset, inset + tick)
                        ctx.lineTo(inset, inset)
                        ctx.lineTo(inset + tick, inset)
                        ctx.moveTo(w - inset - tick, inset)
                        ctx.lineTo(w - inset, inset)
                        ctx.lineTo(w - inset, inset + tick)
                        ctx.moveTo(w - inset, h - inset - tick)
                        ctx.lineTo(w - inset, h - inset)
                        ctx.lineTo(w - inset - tick, h - inset)
                        ctx.moveTo(inset + tick, h - inset)
                        ctx.lineTo(inset, h - inset)
                        ctx.lineTo(inset, h - inset - tick)
                        ctx.stroke()
                        ctx.globalAlpha = 1
                    }
                }

                GlitchText {
                    id: tag
                    width: tagFit.width
                    anchors.centerIn: parent
                    opacity: chip.textOn
                    horizontalAlignment: Text.AlignHCenter
                    value: chip.dying ? "DISCONNECTED" : "CALL CONNECTED"
                    settled: chip.settled && chip.slotOpen && chip.textOn > 0.4
                    glitchOnChange: true
                    color: Theme.text
                    font.family: Theme.fontHud
                    font.pixelSize: 14
                    font.letterSpacing: 0.6
                    font.bold: true
                }
            }

            Item {
                id: waveBay
                anchors.left: labelPad.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: width > 1
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    width: parent.width * chip.bay
                    height: 2
                    color: chip.fill
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * chip.bay
                    height: 2
                    color: chip.fill
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: chip.fill
                    opacity: chip.bay
                }

                Rectangle {
                    width: 4
                    height: 4
                    rotation: 45
                    color: chip.fill
                    visible: chip.trace > 0.02 && !chip.waveOn
                    opacity: Math.min(1, chip.trace * 5)
                    anchors.centerIn: parent
                }

                Rectangle {
                    height: 2
                    width: Math.max(0, (parent.width - 8) * chip.trace)
                    anchors.centerIn: parent
                    color: Theme.text
                    visible: chip.trace > 0 && !chip.waveOn
                    opacity: 0.9
                }

                VoiceWave {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    live: chip.slotOpen && chip.waveOn
                    peak: CallWatch.peak
                    collapse: chip.waveOn ? (chip.dying ? chip.drain : 1) : 0
                    ink: Theme.text
                    opacity: chip.waveOn ? 1 : 0
                }
            }
        }
    }
}
