import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 340
    paneHeight: 400

    onOpenChanged: {
        if (open) {
            if (Bt.powered)
                Bt.scan(true)
        } else {
            Bt.scan(false)
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            spacing: 8

            GlitchText {
                value: "SYS // BT"
                settled: true
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 10
                font.letterSpacing: 1.8
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

            Text {
                text: Bt.statusLine
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 9
                elide: Text.ElideRight
                width: 160
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        HudRow {
            width: parent.width
            label: !Bt.available ? "NO RADIO" : (Bt.powered ? "RADIO ON" : "RADIO OFF")
            hint: !Bt.available ? "WAIT" : (Bt.powered ? "DISABLE" : "ENABLE")
            active: Bt.powered
            enabled: Bt.available
            onClicked: Bt.togglePower()
        }

        HudRow {
            width: parent.width
            label: Bt.scanning ? "SCANNING…" : "SCAN"
            hint: Bt.scanning ? "///" : "RUN"
            enabled: Bt.powered
            onClicked: Bt.toggleScan()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            text: Bt.linked ? "ACTIVE NODES" : "KNOWN NODES"
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 7
            font.letterSpacing: 1.4
            font.bold: true
        }

        Flickable {
            width: parent.width
            height: 220
            clip: true
            contentHeight: listCol.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: listCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: Bt.devices

                    HudRow {
                        required property var modelData
                        width: listCol.width
                        label: Bt.deviceLabel(modelData)
                        hint: Bt.deviceHint(modelData)
                        active: modelData.connected
                        enabled: Bt.powered
                        onClicked: Bt.activate(modelData)
                    }
                }

                Text {
                    visible: !Bt.devices || !Bt.devices.values || Bt.devices.values.length === 0
                    text: !Bt.available ? "NO ADAPTER" : (Bt.powered ? "NO NODES IN RANGE" : "RADIO DISABLED")
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }
        }
    }
}
