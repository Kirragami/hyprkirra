import Quickshell.Services.Pipewire
import QtQuick
import "../fui"

Item {
    id: row

    property var node: null
    property int ticks: 16

    implicitWidth: 280
    implicitHeight: row.mediaName.length > 0 ? 56 : 44

    PwObjectTracker {
        objects: row.node ? [row.node] : []
    }

    readonly property bool ready: row.node !== null && row.node.ready && row.node.audio !== null
    readonly property bool muted: row.ready ? row.node.audio.muted : false
    readonly property int percent: {
        if (!row.ready || row.muted)
            return 0
        return Math.round(Math.min(1, row.node.audio.volume) * 100)
    }

    readonly property string appName: {
        const n = row.node
        if (!n)
            return "STREAM"
        let app = n.nickname || n.description || n.name || "STREAM"
        if (n.ready) {
            const props = n.properties || {}
            app = props["application.name"] || app
        }
        return String(app).toUpperCase()
    }

    readonly property string mediaName: {
        const n = row.node
        if (!n || !n.ready)
            return ""
        const props = n.properties || {}
        const media = props["media.name"]
        if (!media)
            return ""
        const text = String(media).trim()
        if (text.length === 0)
            return ""
        if (text.toUpperCase() === row.appName)
            return ""
        return text
    }

    function setVol(v: real): void {
        if (!row.ready)
            return
        row.node.audio.muted = false
        row.node.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute(): void {
        if (row.ready)
            row.node.audio.muted = !row.node.audio.muted
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        color: hover.hovered ? Theme.bgRaised : "transparent"
        border.color: hover.hovered ? Theme.lineDim : "transparent"
        border.width: 1
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 3

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.right: pctMark.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.appName
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                id: pctMark
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.muted ? "MUTE" : (row.percent + "")
                color: row.muted ? Theme.textMute : Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: row.toggleMute()
            }
        }

        Text {
            visible: row.mediaName.length > 0
            width: parent.width
            height: visible ? 10 : 0
            text: row.mediaName
            color: Theme.textMute
            font.family: Theme.fontMono
            font.pixelSize: 8
            elide: Text.ElideRight
        }

        Item {
            id: slider
            width: parent.width
            height: 12

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: row.ticks
                    Rectangle {
                        required property int index
                        width: Math.max(2, (slider.width - (row.ticks - 1) * 2) / row.ticks)
                        height: 10
                        color: !row.muted && index < Math.round(row.percent / 100 * row.ticks) ? Theme.line : "transparent"
                        border.color: Theme.lineFaint
                        border.width: 1
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        row.toggleMute()
                    else
                        row.setVol(mouse.x / Math.max(1, width))
                }
                onPositionChanged: mouse => {
                    if (pressedButtons & Qt.LeftButton)
                        row.setVol(mouse.x / Math.max(1, width))
                }
                onWheel: w => {
                    if (!row.ready)
                        return
                    const dir = w.angleDelta.y > 0 ? 1 : -1
                    row.setVol(row.node.audio.volume + dir * 0.05)
                }
            }
        }
    }
}
