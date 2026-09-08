pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int span: 300
    readonly property int tickMs: 1000

    property real rxBps: 0
    property real txBps: 0
    property real rxN: 0
    property real txN: 0
    property var rxHist: root.zeros()
    property var txHist: root.zeros()
    property int gen: 0
    property bool ready: false

    property real _rxPrev: 0
    property real _txPrev: 0
    property bool _primed: false

    readonly property string rxLine: "RX  " + root.fmtBps(root.rxBps)
    readonly property string txLine: "TX  " + root.fmtBps(root.txBps)
    readonly property string rateLine: root.rxLine + " // " + root.txLine

    function zeros(): var {
        const a = []
        for (let i = 0; i < root.span; i++)
            a.push(0)
        return a
    }

    function skipIface(name: string): bool {
        const n = (name || "").toLowerCase()
        return n === "lo"
            || n.indexOf("docker") === 0
            || n.indexOf("veth") === 0
            || n.indexOf("br-") === 0
            || n.indexOf("virbr") === 0
    }

    function fmtBps(n: real): string {
        const v = Math.max(0, n)
        if (v >= 1073741824)
            return (v / 1073741824).toFixed(1) + "G"
        if (v >= 1048576)
            return (v / 1048576).toFixed(1) + "M"
        if (v >= 1024)
            return (v / 1024).toFixed(1) + "K"
        return Math.round(v) + "B"
    }

    function parse(raw: string): void {
        const lines = (raw || "").split("\n")
        let rx = 0
        let tx = 0
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const cut = line.indexOf(":")
            if (cut < 0)
                continue
            const name = line.slice(0, cut).trim()
            if (root.skipIface(name))
                continue
            const bits = line.slice(cut + 1).trim().split(/\s+/)
            if (bits.length < 10)
                continue
            rx += Number(bits[0]) || 0
            tx += Number(bits[8]) || 0
        }

        if (!root._primed) {
            root._rxPrev = rx
            root._txPrev = tx
            root._primed = true
            return
        }

        const dt = root.tickMs / 1000
        const rxRate = Math.max(0, (rx - root._rxPrev) / dt)
        const txRate = Math.max(0, (tx - root._txPrev) / dt)
        root._rxPrev = rx
        root._txPrev = tx
        root.rxBps = rxRate
        root.txBps = txRate

        const rh = root.rxHist.slice()
        const th = root.txHist.slice()
        rh.push(rxRate)
        th.push(txRate)
        if (rh.length > root.span)
            rh.shift()
        if (th.length > root.span)
            th.shift()
        root.rxHist = rh
        root.txHist = th

        let peak = 1048576
        for (let i = 0; i < rh.length; i++) {
            if (rh[i] > peak)
                peak = rh[i]
            if (th[i] > peak)
                peak = th[i]
        }
        root.rxN = Math.max(0, Math.min(1, rxRate / peak))
        root.txN = Math.max(0, Math.min(1, txRate / peak))
        root.gen += 1
        root.ready = true
    }

    Process {
        id: probe
        command: ["sh", "-c", "cat /proc/net/dev"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: kick.restart()
    }

    Timer {
        id: kick
        interval: root.tickMs
        onTriggered: probe.running = true
    }
}
