import QtQuick

HudPick {
    id: pip
    property bool live: true
    property bool settled: true
    property string label: "LINK"
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

            Rectangle {
                width: 10
                height: 10
                rotation: 45
                color: pip.live ? "#3ee06a" : "#f3f3f3"
                border.width: 0
                anchors.centerIn: parent

                SequentialAnimation on opacity {
                    running: pip.live
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
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
