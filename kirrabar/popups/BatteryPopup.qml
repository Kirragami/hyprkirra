import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 280
    paneHeight: 196

    property int percent: 0
    property bool discharging: true
    property string eta: "—"
    property string rate: "—"

    Column {
        anchors.fill: parent
        spacing: 10

        GlitchText {
            value: "SYS // POWER"
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
            text: pop.percent + "%"
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 26
            font.bold: true
            font.letterSpacing: 1.6
        }

        Row {
            spacing: 3
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    width: 13
                    height: 14
                    color: index < Math.round(pop.percent / 100 * 16) ? Theme.line : "transparent"
                    border.color: Theme.lineFaint
                    border.width: 1
                }
            }
        }

        Text {
            text: (pop.discharging ? "DISCHARGE" : "AC LINK") + "  ·  " + pop.eta
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 9
        }

        Text {
            text: pop.rate
            color: Theme.textMute
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }
}
