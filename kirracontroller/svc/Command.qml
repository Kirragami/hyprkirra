pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: cmd

    property bool armed: false
    property string mode: ""

    signal power()
    signal close()

    function callPower(): void {
        if (cmd.armed && cmd.mode === "power") {
            cmd.armed = false
            cmd.mode = ""
            cmd.close()
            return
        }
        cmd.mode = "power"
        cmd.armed = true
        cmd.power()
    }

    function dismiss(): void {
        if (!cmd.armed)
            return
        cmd.armed = false
        cmd.mode = ""
        cmd.close()
    }
}
