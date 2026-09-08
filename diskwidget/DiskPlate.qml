import QtQuick
import "svc"

Item {
    id: plate
    property bool live: false
    property int phase: 0
    property real span: 240

    implicitWidth: plate.span
    implicitHeight: col.implicitHeight
    width: implicitWidth
    height: implicitHeight
    clip: true
    opacity: plate.live ? 1 : 0
    visible: opacity > 0.02

    readonly property int lastPhase: Disk.hasHome ? 4 : 3

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
            if (plate.phase >= plate.lastPhase)
                stagger.stop()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 4

        GlitchText {
            value: "SYS // DISK"
            settled: plate.live && plate.phase >= 1
            glitchOnChange: false
            color: Theme.textMute
            font.family: Theme.fontHud
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.bold: true
        }

        GlitchText {
            width: parent.width
            value: Disk.diskLine
            settled: plate.live && plate.phase >= 2
            glitchOnChange: false
            color: Theme.line
            font.pixelSize: 13
            font.letterSpacing: 1.1
            elide: Text.ElideRight
        }

        GlitchText {
            width: parent.width
            value: Disk.ioLine
            settled: plate.live && plate.phase >= 3
            glitchOnChange: false
            color: Theme.warn
            font.pixelSize: 12
            font.letterSpacing: 1.0
            elide: Text.ElideRight
        }

        GlitchText {
            visible: Disk.hasHome
            width: parent.width
            value: Disk.homeLine
            settled: plate.live && plate.phase >= 4
            glitchOnChange: false
            color: Theme.textDim
            font.pixelSize: 12
            font.letterSpacing: 1.0
            elide: Text.ElideRight
        }
    }
}
