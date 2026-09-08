pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int tickMs: 1000

    property int pct: 0
    property real usedGi: 0
    property real totalGi: 0
    property bool ready: false
    property bool hasHome: false
    property int homePct: 0
    property real homeUsedGi: 0
    property real homeTotalGi: 0
    property int ioPct: 0
    property real readBps: 0
    property real writeBps: 0
    property string dev: ""

    property real _rsec: 0
    property real _wsec: 0
    property real _ioTicks: 0
    property bool _ioPrimed: false
    property string _want: ""

    readonly property string diskLine: "DISK  " + root.fmtGi(root.usedGi) + " // " + root.fmtGi(root.totalGi) + " // " + root.pct + "%"
    readonly property string ioLine: "IO    " + root.fmtBps(root.readBps) + " R // " + root.fmtBps(root.writeBps) + " W // " + root.ioPct + "%"
    readonly property string homeLine: "HOME  " + root.fmtGi(root.homeUsedGi) + " // " + root.fmtGi(root.homeTotalGi) + " // " + root.homePct + "%"

    function fmtGi(g: real): string {
        if (!isFinite(g) || g < 0)
            return "0.0G"
        if (g >= 1024)
            return (g / 1024).toFixed(1) + "T"
        return g.toFixed(1) + "G"
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

    function toGi(bytes: real): real {
        return bytes / 1073741824
    }

    function baseName(src: string): string {
        const s = String(src || "").trim()
        const cut = s.lastIndexOf("/")
        return cut >= 0 ? s.slice(cut + 1) : s
    }

    function parentName(n: string): string {
        const nvme = n.match(/^(nvme\d+n\d+)p\d+$/)
        if (nvme)
            return nvme[1]
        const mmc = n.match(/^(mmcblk\d+)p\d+$/)
        if (mmc)
            return mmc[1]
        const sd = n.match(/^([shv]d[a-z]+)\d+$/)
        if (sd)
            return sd[1]
        const xvd = n.match(/^(xvd[a-z]+)\d+$/)
        if (xvd)
            return xvd[1]
        return n
    }

    function skipIo(n: string): bool {
        const s = (n || "").toLowerCase()
        return s.indexOf("loop") === 0 || s.indexOf("ram") === 0 || s.indexOf("zram") === 0
            || s.indexOf("sr") === 0 || s === "fd0"
    }

    function parseDf(raw: string): void {
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
        const base = root.baseName(rootSrc)
        root._want = base
        root.ready = true
    }

    function pickStats(lines: var, want: string): var {
        const names = []
        if (want && want.length) {
            names.push(want)
            const par = root.parentName(want)
            if (par !== want)
                names.push(par)
        }
        for (let n = 0; n < names.length; n++) {
            for (let i = 0; i < lines.length; i++) {
                const p = lines[i].trim().split(/\s+/)
                if (p.length >= 13 && p[2] === names[n])
                    return p
            }
        }
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].trim().split(/\s+/)
            if (p.length < 13)
                continue
            if (root.skipIo(p[2]))
                continue
            return p
        }
        return null
    }

    function parseIo(raw: string): void {
        const lines = (raw || "").split("\n")
        const p = root.pickStats(lines, root._want)
        if (!p)
            return

        root.dev = p[2]
        const rsec = Number(p[5]) || 0
        const wsec = Number(p[9]) || 0
        const ioTicks = Number(p[12]) || 0

        if (!root._ioPrimed) {
            root._rsec = rsec
            root._wsec = wsec
            root._ioTicks = ioTicks
            root._ioPrimed = true
            return
        }

        const dt = root.tickMs / 1000
        const dr = Math.max(0, rsec - root._rsec)
        const dw = Math.max(0, wsec - root._wsec)
        const dio = Math.max(0, ioTicks - root._ioTicks)
        root._rsec = rsec
        root._wsec = wsec
        root._ioTicks = ioTicks

        root.readBps = dr * 512 / dt
        root.writeBps = dw * 512 / dt
        let util = dio / (dt * 1000)
        if (util < 0.01 && (root.readBps + root.writeBps) > 0)
            util = Math.min(1, (root.readBps + root.writeBps) / 209715200)
        root.ioPct = Math.max(0, Math.min(100, Math.round(util * 100)))
    }

    function parse(raw: string): void {
        const text = raw || ""
        const cut = text.indexOf("\n---\n")
        if (cut < 0) {
            root.parseDf(text)
            return
        }
        root.parseDf(text.slice(0, cut))
        root.parseIo(text.slice(cut + 5))
    }

    Process {
        id: probe
        command: ["sh", "-c", "df -B1 -P / /home 2>/dev/null; echo ---; cat /proc/diskstats"]
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
