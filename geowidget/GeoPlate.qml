import QtQuick
import "svc"

Item {
    id: plate
    property bool live: false
    property int phase: 0

    property real span: 360

    implicitWidth: plate.span
    implicitHeight: col.implicitHeight
    width: implicitWidth
    height: implicitHeight
    clip: true
    opacity: plate.live ? 1 : 0
    visible: opacity > 0.02

    readonly property string lanLine: Locate.localIp.length ? Locate.localIp : "UNKNOWN"
    readonly property string wanLine: Locate.online && Locate.ip.length ? Locate.ip : "UNKNOWN"

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    onLiveChanged: {
        plate.phase = 0
        stagger.stop()
        if (plate.live)
            stagger.restart()
    }

    Timer {
        id: stagger
        interval: 60
        repeat: true
        onTriggered: {
            plate.phase += 1
            if (plate.phase >= 4)
                stagger.stop()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 4

        GlitchText {
            value: Locate.online && Locate.ip.length ? "GEO // FIX" : (Locate.online ? "GEO // SCAN" : "GEO // HOLD")
            settled: plate.live && plate.phase >= 1
            glitchOnChange: true
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.bold: true
        }

        GlitchText {
            width: parent.width
            value: Locate.countryLine === "—" ? "----" : Locate.countryLine
            settled: plate.live && plate.phase >= 2
            glitchOnChange: true
            color: Theme.text
            font.pixelSize: 13
            font.letterSpacing: 1.1
            elide: Text.ElideRight
        }

        GlitchText {
            width: parent.width
            value: Locate.coordLine === "—" ? "----" : Locate.coordLine
            settled: plate.live && plate.phase >= 3
            glitchOnChange: true
            color: Theme.textDim
            font.pixelSize: 12
            font.letterSpacing: 1.0
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 0

            GlitchText {
                id: lanMark
                value: plate.lanLine + " // "
                settled: plate.live && plate.phase >= 4
                glitchOnChange: true
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: 12
                font.letterSpacing: 0.6
            }

            GlitchText {
                width: Math.max(24, parent.width - lanMark.width)
                value: plate.wanLine
                settled: plate.live && plate.phase >= 4
                glitchOnChange: true
                color: Theme.warn
                font.family: Theme.fontMono
                font.pixelSize: 12
                font.letterSpacing: 0.6
                elide: Text.ElideRight
            }
        }
    }
}
