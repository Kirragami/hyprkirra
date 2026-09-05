import QtQuick

HudPick {
    id: meter
    property string label: "CPU"
    property int value: 0
    property int segments: 8
    property bool interactive: false
    property bool settled: true

    signal wheel(int dir)
    signal clicked()
    signal rightClicked()

    implicitWidth: col.implicitWidth
    implicitHeight: 34

    readonly property int clamped: Math.max(0, Math.min(100, meter.value))
    readonly property int lit: Math.round(clamped / 100 * segments)

    Column {
        id: col
        spacing: 3
        anchors.verticalCenter: parent.verticalCenter

        GlitchText {
            value: meter.label + " " + meter.clamped
            settled: meter.settled
            glitchOnChange: false
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.2
            font.bold: true
        }

        Row {
            spacing: 2

            Repeater {
                model: meter.segments
                Rectangle {
                    required property int index
                    width: 5
                    height: 14
                    color: index < meter.lit ? Theme.line : "transparent"
                    border.color: index < meter.lit ? Theme.line : Theme.lineFaint
                    border.width: 1
                    opacity: index < meter.lit ? (0.45 + 0.55 * ((index + 1) / meter.segments)) : 0.7

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: meter.interactive
        hoverEnabled: meter.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: meter.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                meter.rightClicked()
            else
                meter.clicked()
        }
        onWheel: w => meter.wheel(w.angleDelta.y > 0 ? 1 : -1)
    }
}
