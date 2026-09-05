import Quickshell
import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 248
    paneHeight: 230

    function run(cmd: var): void {
        Quickshell.execDetached(cmd)
        pop.dismiss()
    }

    Column {
        anchors.fill: parent
        spacing: 6

        GlitchText {
            value: "SYS // POWER"
            settled: pop.live
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

        HudRow {
            width: parent.width
            label: "LOCK"
            hint: "SCRN"
            onClicked: pop.run(["hyprlock"])
        }

        HudRow {
            width: parent.width
            label: "SUSPEND"
            hint: "SLEEP"
            onClicked: pop.run(["systemctl", "suspend"])
        }

        HudRow {
            width: parent.width
            label: "LOGOUT"
            hint: "EXIT"
            onClicked: pop.run(["hyprctl", "dispatch", "exit"])
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        HudRow {
            width: parent.width
            label: "REBOOT"
            hint: "RST"
            onClicked: pop.run(["systemctl", "reboot"])
        }

        HudRow {
            width: parent.width
            label: "SHUTDOWN"
            hint: "HALT"
            onClicked: pop.run(["systemctl", "poweroff"])
        }
    }
}
