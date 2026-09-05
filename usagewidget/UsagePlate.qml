import QtQuick
import "svc"

Item {
    id: plate
    property bool live: false
    property int phase: 0

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    width: implicitWidth
    height: implicitHeight
    opacity: plate.live ? 1 : 0
    visible: opacity > 0.02

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
            if (plate.phase >= 3)
                stagger.stop()
        }
    }

    Column {
        id: col
        spacing: 4

        GlitchText {
            value: "SYS // CORE"
            settled: plate.live && plate.phase >= 1
            glitchOnChange: false
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.bold: true
        }

        GlitchText {
            value: Usage.cpuLine
            settled: plate.live && plate.phase >= 2
            glitchOnChange: false
            color: Theme.line
            font.pixelSize: 13
            font.letterSpacing: 1.1
        }

        GlitchText {
            value: Usage.ramLine
            settled: plate.live && plate.phase >= 3
            glitchOnChange: false
            color: Theme.warn
            font.pixelSize: 12
            font.letterSpacing: 1.0
        }
    }
}
