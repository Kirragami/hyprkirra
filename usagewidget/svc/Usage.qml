pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpu: 0
    property int mem: 0
    property int cores: 0
    property int threads: 0
    property real usedGi: 0
    property real totalGi: 0
    property bool ready: false

    property int _prevIdle: 0
    property int _prevTotal: 0
    property bool _cpuPrimed: false

    readonly property string cpuLine: {
        const c = root.cores > 0 ? root.cores + "C" : "--"
        const t = root.threads > 0 ? root.threads + "T" : "--"
        return "CPU  " + c + " // " + t + " // " + root.cpu + "%"
    }
    readonly property string ramLine: "RAM  " + root.usedGi.toFixed(1) + "G // " + root.totalGi.toFixed(1) + "G // " + root.mem + "%"

    function parse(raw: string): void {
        const lines = (raw || "").trim().split("\n")
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
        if (memTotal > 0) {
            const used = Math.max(0, memTotal - memAvail)
            root.mem = Math.max(0, Math.min(100, Math.round(used / memTotal * 100)))
            root.totalGi = memTotal / 1048576
            root.usedGi = used / 1048576
        }

        root.ready = true
    }

    function parseTopo(raw: string): void {
        const parts = (raw || "").trim().split(/\s+/)
        const cores = Number(parts[0]) || 0
        const threads = Number(parts[1]) || 0
        if (threads > 0) {
            root.cores = cores > 0 ? cores : threads
            root.threads = threads
        }
    }

    Process {
        command: [
            "sh", "-c",
            "awk '"
            + "/^processor/ { t++ } "
            + "/^physical id/ { p=$4 } "
            + "/^core id/ { k[p\",\"$4]=1 } "
            + "END { c=0; for (i in k) c++; if (c<1) c=t; print c, t }' /proc/cpuinfo"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseTopo(text)
        }
    }

    Process {
        id: probe
        command: [
            "sh", "-c",
            "grep '^cpu ' /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: kick.restart()
    }

    Timer {
        id: kick
        interval: 1000
        onTriggered: probe.running = true
    }
}
