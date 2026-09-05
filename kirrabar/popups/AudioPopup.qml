import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 320
    paneHeight: 400

    property var sink: null
    property bool ready: false
    property bool muted: false
    property int percent: 0

    readonly property int streamCount: {
        let n = 0
        const groups = links.linkGroups
        for (let i = 0; i < groups.length; i++) {
            const src = groups[i].source
            if (src && src.audio && src.isStream)
                n++
        }
        return n
    }

    PwNodeLinkTracker {
        id: links
        node: pop.sink
    }

    PwObjectTracker {
        objects: {
            const out = []
            const groups = links.linkGroups
            for (let i = 0; i < groups.length; i++) {
                const src = groups[i].source
                if (src)
                    out.push(src)
            }
            return out
        }
    }

    function setVol(v: real): void {
        if (!pop.ready)
            return
        pop.sink.audio.muted = false
        pop.sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    function isAppStream(node: var): bool {
        return node && node.audio && node.isStream
    }

    Column {
        anchors.fill: parent
        spacing: 8

        GlitchText {
            value: "SYS // AUDIO"
            settled: true
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 10
            font.letterSpacing: 1.8
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            text: pop.muted ? "MUTE" : (pop.percent + " / 100")
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 22
            font.bold: true
            font.letterSpacing: 1.4
        }

        Item {
            id: slider
            width: parent.width
            height: 20

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: 20
                    Rectangle {
                        required property int index
                        width: (slider.width - 57) / 20
                        height: 14
                        color: !pop.muted && index < Math.round(pop.percent / 5) ? Theme.line : "transparent"
                        border.color: Theme.lineFaint
                        border.width: 1
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => pop.setVol(mouse.x / Math.max(1, width))
                onPositionChanged: mouse => {
                    if (pressed)
                        pop.setVol(mouse.x / Math.max(1, width))
                }
            }
        }

        HudRow {
            width: parent.width
            label: pop.muted ? "UNMUTE" : "MUTE OUTPUT"
            hint: pop.muted ? "OFF" : "ON"
            active: pop.muted
            onClicked: {
                if (pop.ready)
                    pop.sink.audio.muted = !pop.sink.audio.muted
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            text: pop.streamCount > 0 ? ("APPS  " + String(pop.streamCount).padStart(2, "0")) : "APPS"
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 7
            font.letterSpacing: 1.4
            font.bold: true
        }

        Flickable {
            width: parent.width
            height: 168
            clip: true
            contentHeight: listCol.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: listCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: links.linkGroups

                    MixRow {
                        required property var modelData
                        width: listCol.width
                        visible: pop.isAppStream(modelData.source)
                        height: visible ? implicitHeight : 0
                        node: modelData.source
                    }
                }

                Text {
                    visible: pop.streamCount === 0
                    text: "NO ACTIVE STREAMS"
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }
        }
    }
}
