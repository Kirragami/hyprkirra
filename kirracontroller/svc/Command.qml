pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: cmd

    property bool armed: false
    property string mode: ""

    signal power()
    signal search()
    signal close()

    function callPower(): void {
        if (cmd.armed && cmd.mode === "power") {
            cmd.dismiss()
            return
        }
        cmd.mode = "power"
        cmd.armed = true
        cmd.power()
    }

    function callSearch(): void {
        if (cmd.armed && cmd.mode === "search") {
            cmd.dismiss()
            return
        }
        cmd.mode = "search"
        cmd.armed = true
        cmd.search()
    }

    function dismiss(): void {
        if (!cmd.armed)
            return
        cmd.armed = false
        cmd.mode = ""
        cmd.close()
    }
}
