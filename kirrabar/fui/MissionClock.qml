import Quickshell
import QtQuick

HudPick {
    id: clock
    property bool settled: true
    readonly property alias spout: drop
    lockPad: 10
    zoom: 1.1
    signal clicked()
    implicitWidth: col.implicitWidth + 44
    implicitHeight: 44

    Item {
        id: drop
        width: 1
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: clock.height / 2 + clock.lockR
    }

    SystemClock {
        id: sys
        precision: SystemClock.Seconds
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "⟨⟨"
            color: Theme.lineDim
            font.family: Theme.fontMono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
            }
        }

        Column {
            id: col
            spacing: 1

            GlitchText {
                anchors.horizontalCenter: parent.horizontalCenter
                value: "SYS TIME"
                settled: clock.settled
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 9
                font.letterSpacing: 2.2
                font.bold: true
                topPadding: 5
            }

            GlitchText {
                anchors.horizontalCenter: parent.horizontalCenter
                value: Qt.formatDateTime(sys.date, "HH:mm:ss")
                settled: clock.settled
                glitchOnChange: false
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 20
                font.bold: true
                font.letterSpacing: 1.5
            }

            GlitchText {
                anchors.horizontalCenter: parent.horizontalCenter
                value: Qt.formatDateTime(sys.date, "dd · MMM · yyyy").toUpperCase()
                settled: clock.settled
                glitchOnChange: false
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.6
                transform: Translate { y: -4 }
            }
        }

        Text {
            text: "⟩⟩"
            color: Theme.lineDim
            font.family: Theme.fontMono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clock.clicked()
    }
}
