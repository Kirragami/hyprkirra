import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 400
    paneHeight: 480

    Column {
        id: col
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            spacing: 8

            GlitchText {
                value: "SYS // MAIL"
                settled: true
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 12
                font.letterSpacing: 1.8
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

            Text {
                text: Notifs.statusLine
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                elide: Text.ElideRight
                width: 180
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
            label: "CLEAR ALL"
            hint: Notifs.pending ? String(Notifs.count) : "—"
            enabled: Notifs.pending
            onClicked: Notifs.clearAll()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Text {
            text: "PENDING"
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.4
            font.bold: true
        }

        Flickable {
            width: parent.width
            height: Math.max(120, col.height - y)
            clip: true
            contentHeight: listCol.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: listCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: Notifs.items

                    Item {
                        id: card
                        required property var modelData
                        width: listCol.width
                        height: bodyLine.visible ? 80 : 50

                        readonly property string iconSrc: Notifs.icon(modelData)
                        readonly property string bodyText: Notifs.body(modelData)

                        Rectangle {
                            anchors.fill: parent
                            color: hit.containsMouse ? Theme.bgRaised : "transparent"
                            border.color: hit.containsMouse ? Theme.lineDim : "transparent"
                            border.width: 1
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Rectangle {
                                id: pip
                                width: 6
                                height: 6
                                rotation: 45
                                color: card.modelData && card.modelData.urgency === 2 ? Theme.warn : "transparent"
                                border.color: Theme.lineDim
                                border.width: 1
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 12
                            }

                            Image {
                                id: glyph
                                visible: card.iconSrc.length > 0
                                source: card.iconSrc
                                width: 20
                                height: 20
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                anchors.left: pip.right
                                anchors.leftMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                text: Notifs.hint(card.modelData)
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                            }

                            Text {
                                id: appLine
                                text: Notifs.appLabel(card.modelData).toUpperCase()
                                color: Theme.textMute
                                font.family: Theme.fontHud
                                font.pixelSize: 10
                                font.letterSpacing: 1.2
                                font.bold: true
                                elide: Text.ElideRight
                                anchors.left: glyph.visible ? glyph.right : pip.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 44
                                anchors.top: parent.top
                                anchors.topMargin: 6
                            }

                            Text {
                                width: parent.width - (glyph.visible ? 52 : 22)
                                text: Notifs.summary(card.modelData)
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                anchors.left: glyph.visible ? glyph.right : pip.right
                                anchors.leftMargin: 8
                                anchors.top: appLine.bottom
                                anchors.topMargin: 2
                            }

                            Text {
                                id: bodyLine
                                visible: card.bodyText.length > 0
                                width: parent.width - (glyph.visible ? 52 : 22)
                                text: card.bodyText
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                anchors.left: glyph.visible ? glyph.right : pip.right
                                anchors.leftMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                            }
                        }

                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismiss(card.modelData)
                        }
                    }
                }

                Text {
                    visible: Notifs.pending && Notifs.items.length === 0
                    text: Notifs.count + " HELD BY SWAYNC"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }

                Text {
                    visible: !Notifs.pending
                    text: "NO PENDING"
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }
        }
    }
}
