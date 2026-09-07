pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int pct: 0
    property real usedGi: 0
    property real totalGi: 0
    property bool ready: false
    property bool hasHome: false
    property int homePct: 0
    property real homeUsedGi: 0
    property real homeTotalGi: 0

    readonly property string diskLine: "DISK  " + root.fmtGi(root.usedGi) + " // " + root.fmtGi(root.totalGi) + " // " + root.pct + "%"
    readonly property string homeLine: "HOME  " + root.fmtGi(root.homeUsedGi) + " // " + root.fmtGi(root.homeTotalGi) + " // " + root.homePct + "%"

    function fmtGi(g: real): string {
        if (!isFinite(g) || g < 0)
            return "0.0G"
        if (g >= 1024)
            return (g / 1024).toFixed(1) + "T"
        return g.toFixed(1) + "G"
    }

    function toGi(bytes: real): real {
        return bytes / 1073741824
    }

    function parse(raw: string): void {
        const lines = (raw || "").trim().split("\n")
        let rootUsed = 0
        let rootTotal = 0
        let rootSrc = ""
        let homeUsed = 0
        let homeTotal = 0
        let homeSrc = ""
        let sawRoot = false
        let sawHome = false

        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].trim().split(/\s+/)
            if (p.length < 6)
                continue
            const src = p[0]
            const total = Number(p[1]) || 0
            const used = Number(p[2]) || 0
            const mount = p[p.length - 1]
            if (mount === "/") {
                sawRoot = true
                rootSrc = src
                rootTotal = total
                rootUsed = used
            } else if (mount === "/home") {
                sawHome = true
                homeSrc = src
                homeTotal = total
                homeUsed = used
            }
        }

        if (!sawRoot)
            return

        root.totalGi = root.toGi(rootTotal)
        root.usedGi = root.toGi(rootUsed)
        root.pct = rootTotal > 0 ? Math.max(0, Math.min(100, Math.round(rootUsed / rootTotal * 100))) : 0
        root.hasHome = sawHome && homeSrc.length && homeSrc !== rootSrc && homeTotal > 0
        if (root.hasHome) {
            root.homeTotalGi = root.toGi(homeTotal)
            root.homeUsedGi = root.toGi(homeUsed)
            root.homePct = Math.max(0, Math.min(100, Math.round(homeUsed / homeTotal * 100)))
        }
        root.ready = true
    }

    Process {
        id: probe
        command: ["sh", "-c", "df -B1 -P / /home 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: kick.restart()
    }

    Timer {
        id: kick
        interval: 5000
        onTriggered: probe.running = true
    }
}
