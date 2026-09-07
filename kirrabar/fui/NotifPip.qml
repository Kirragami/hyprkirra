import QtQuick

HudPick {
    id: pip
    property bool pending: false
    property bool settled: true
    property string label: "ALERTS"
    signal clicked()
    implicitWidth: col.implicitWidth
    implicitHeight: 34

    Column {
        id: col
        spacing: 3
        anchors.verticalCenter: parent.verticalCenter

        GlitchText {
            id: tag
            width: Math.max(implicitWidth, 14)
            value: pip.label
            settled: pip.settled
            glitchOnChange: false
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.2
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            width: tag.width
            height: 14

            Text {
                id: glyph
                anchors.centerIn: parent
                text: "\uf0e0"
                color: pip.pending ? Theme.warn : "#f3f3f3"
                font.family: Theme.fontMono
                font.pixelSize: 13
                opacity: 1

                SequentialAnimation on opacity {
                    id: pulse
                    running: pip.pending
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.28; duration: 640; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 640; easing.type: Easing.InOutSine }
                    onRunningChanged: {
                        if (!running)
                            glyph.opacity = 1
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pip.clicked()
    }
}
