import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 340
    paneHeight: 440

    onOpenChanged: {
        if (open) {
            Network.needsPassword = false
            Network.refresh(true)
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            spacing: 8

            GlitchText {
                value: "SYS // LINK"
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
                text: Network.statusLine
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 9
                elide: Text.ElideRight
                width: 140
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
            label: Network.wifiOn ? "RADIO ON" : "RADIO OFF"
            hint: Network.wifiOn ? "DISABLE" : "ENABLE"
            active: Network.wifiOn
            onClicked: Network.toggleRadio()
        }

        HudRow {
            width: parent.width
            label: Network.scanning ? "SCANNING…" : "RESCAN"
            hint: Network.scanning ? "///" : "RUN"
            enabled: !Network.scanning && Network.wifiOn
            onClicked: Network.refresh(true)
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            text: Network.wired ? "WIRED UPLINK ACTIVE" : "AVAILABLE NODES"
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 7
            font.letterSpacing: 1.4
            font.bold: true
        }

        Flickable {
            width: parent.width
            height: {
                let h = 220
                if (Network.lastError.length > 0)
                    h -= 28
                if (Network.needsPassword)
                    h -= 40
                return Math.max(96, h)
            }
            clip: true
            contentHeight: listCol.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: listCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: Network.networks

                    HudRow {
                        required property var modelData
                        width: listCol.width
                        label: modelData.ssid
                        hint: modelData.signal + "%"
                        active: modelData.inUse
                        chevron: modelData.secure && !modelData.inUse
                        onClicked: {
                            if (modelData.inUse)
                                return
                            if (modelData.secure) {
                                Network.pendingSsid = modelData.ssid
                                Network.needsPassword = true
                            } else {
                                Network.connectSsid(modelData.ssid, "")
                            }
                        }
                    }
                }

                Text {
                    visible: Network.networks.length === 0
                    text: Network.wifiOn ? "NO NODES IN RANGE" : "RADIO DISABLED"
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }
        }

        Rectangle {
            visible: Network.needsPassword || Network.lastError.length > 0
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            visible: Network.lastError.length > 0
            text: Network.lastError
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 8
            width: parent.width - 28
            wrapMode: Text.Wrap
        }

        Item {
            visible: Network.needsPassword
            width: parent.width
            height: 28

            Row {
                id: keyRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                height: 28
                spacing: 8

                TextInput {
                    id: psk
                    width: Math.max(80, keyRow.width - 76)
                    height: 28
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    clip: true
                    leftPadding: 8
                    rightPadding: 8
                    verticalAlignment: Text.AlignVCenter
                    Keys.onReturnPressed: pop.submitKey()
                    Keys.onEnterPressed: pop.submitKey()

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        color: Theme.bgRaised
                        border.color: psk.activeFocus ? Theme.lineDim : Theme.lineFaint
                        border.width: 1
                    }
                }

                Item {
                    width: 68
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        color: setHit.containsMouse ? Theme.line : Theme.bgRaised
                        border.color: Theme.lineDim
                        border.width: 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "SET"
                        color: setHit.containsMouse ? Theme.ink : Theme.text
                        font.family: Theme.fontHud
                        font.pixelSize: 10
                        font.letterSpacing: 1.4
                        font.bold: true
                    }

                    MouseArea {
                        id: setHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.submitKey()
                    }
                }
            }
        }
    }

    function submitKey(): void {
        Network.connectSsid(Network.pendingSsid, psk.text)
        psk.text = ""
    }
}
