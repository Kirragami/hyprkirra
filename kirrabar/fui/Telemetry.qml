pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpu: 0
    property int mem: 0
    property string netState: "SCAN"
    property bool netUp: false

    property int _prevIdle: 0
    property int _prevTotal: 0
    property bool _cpuPrimed: false

    function parse(raw: string): void {
        const lines = raw.trim().split("\n")
        if (lines.length < 3)
            return

        const cpuParts = lines[0].trim().split(/\s+/)
        const nums = []
        for (let i = 1; i < cpuParts.length; i++)
            nums.push(Number(cpuParts[i]) || 0)

        if (nums.length >= 5) {
            const idle = nums[3] + nums[4]
            let total = 0
            for (let i = 0; i < nums.length; i++)
                total += nums[i]

            if (root._cpuPrimed) {
                const dIdle = idle - root._prevIdle
                const dTotal = total - root._prevTotal
                if (dTotal > 0)
                    root.cpu = Math.max(0, Math.min(100, Math.round((1 - dIdle / dTotal) * 100)))
            }

            root._prevIdle = idle
            root._prevTotal = total
            root._cpuPrimed = true
        }

        const memTotal = Number((lines[1].match(/\d+/) || [0])[0])
        const memAvail = Number((lines[2].match(/\d+/) || [0])[0])
        if (memTotal > 0)
            root.mem = Math.max(0, Math.min(100, Math.round((1 - memAvail / memTotal) * 100)))

        const net = (lines[3] || "unknown").trim().toLowerCase()
        root.netUp = net === "connected" || net.indexOf("full") !== -1 || net === "up"
        if (root.netUp)
            root.netState = "LINK OK"
        else if (net.indexOf("connect") !== -1)
            root.netState = "HANDSHAKE"
        else
            root.netState = "OFFLINE"
    }

    Process {
        id: probe
        command: [
            "sh", "-c",
            "grep '^cpu ' /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; nmcli -t -f STATE general 2>/dev/null | head -1 || echo unknown"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: restart.restart()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: probe.running = true
    }
}
