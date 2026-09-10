pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool watching: false
    property bool probing: false
    property string liveSig: "000000"
    property string busySig: "000000"

    readonly property string home: Quickshell.env("HOME")

    readonly property var nodes: [
        { id: "dgb", label: "DGB VPN", tag: "DGB", kind: "ipsec", key: "dgb-vpn" },
        { id: "ibk", label: "IBK VPN", tag: "IBK", kind: "ipsec", key: "ibk-vpn" },
        { id: "inno", label: "INNO VPN", tag: "INNO", kind: "ipsec", key: "inno-vpn" },
        { id: "aura", label: "AURA VPN", tag: "AURA", kind: "mihomo", key: "aura-vpn" },
        { id: "bss", label: "BSS VPN", tag: "BSS", kind: "mihomo", key: "bss-vpn" },
        { id: "thz", label: "TERAHERTZ VPN", tag: "THZ", kind: "mihomo", key: "do-proxy" }
    ]

    function nodeIndex(id: string): int {
        const list = root.nodes
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return i
        }
        return -1
    }

    function bitSet(sig: string, i: int, on: bool): string {
        if (i < 0 || i >= sig.length)
            return sig
        return sig.substring(0, i) + (on ? "1" : "0") + sig.substring(i + 1)
    }

    function find(id: string): var {
        const i = root.nodeIndex(id)
        if (i < 0)
            return null
        return root.nodes[i]
    }

    function patch(id: string, fields: var): void {
        const i = root.nodeIndex(id)
        if (i < 0)
            return
        if (fields.live !== undefined)
            root.liveSig = root.bitSet(root.liveSig, i, fields.live)
        if (fields.busy !== undefined)
            root.busySig = root.bitSet(root.busySig, i, fields.busy)
    }

    function parse(raw: string): void {
        const lines = (raw || "").trim().split("\n")
        const map = ({})
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/)
            if (parts.length >= 2)
                map[parts[0]] = parts[1] === "1"
        }
        const list = root.nodes
        let live = ""
        for (let i = 0; i < list.length; i++) {
            if (map[list[i].id] !== undefined)
                live += map[list[i].id] ? "1" : "0"
            else
                live += root.liveSig.charAt(i) === "1" ? "1" : "0"
        }
        root.liveSig = live
        root.busySig = "000000"
        root.probing = false
    }

    function probe(): void {
        if (probeProc.running)
            return
        root.probing = true
        probeProc.running = true
    }

    function toggle(id: string): void {
        const n = root.find(id)
        const i = root.nodeIndex(id)
        if (!n || i < 0 || root.busySig.charAt(i) === "1")
            return
        const want = root.liveSig.charAt(i) !== "1"
        root.patch(id, {
            live: want,
            busy: true
        })
        if (n.kind === "ipsec") {
            const act = want ? "up" : "down"
            Quickshell.execDetached(["bash", "-c", "sudo ipsec " + act + " " + n.key])
        } else if (want) {
            const dir = root.home + "/.config/" + n.key
            Quickshell.execDetached(["bash", "-c", "sudo nohup mihomo -d \"" + dir + "\" >/dev/null 2>&1 &"])
        } else {
            Quickshell.execDetached(["bash", "-c", "sudo pkill -f 'mihomo -d.*" + n.key + "'"])
        }
        settle.restart()
    }

    onWatchingChanged: {
        if (root.watching)
            root.probe()
        else
            settle.stop()
    }

    Process {
        id: probeProc
        command: [
            "bash", "-c",
            "printf 'dgb '; sudo ipsec status dgb-vpn 2>/dev/null | grep -q ESTABLISHED && echo 1 || echo 0; "
            + "printf 'ibk '; sudo ipsec status ibk-vpn 2>/dev/null | grep -q ESTABLISHED && echo 1 || echo 0; "
            + "printf 'inno '; sudo ipsec status inno-vpn 2>/dev/null | grep -q ESTABLISHED && echo 1 || echo 0; "
            + "printf 'aura '; pgrep -f '[m]ihomo -d.*aura-vpn' >/dev/null && echo 1 || echo 0; "
            + "printf 'bss '; pgrep -f '[m]ihomo -d.*bss-vpn' >/dev/null && echo 1 || echo 0; "
            + "printf 'thz '; pgrep -f '[m]ihomo -d.*do-proxy' >/dev/null && echo 1 || echo 0"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: {
            if (root.watching)
                poll.restart()
        }
    }

    Timer {
        id: poll
        interval: 1600
        onTriggered: {
            if (root.watching)
                root.probe()
        }
    }

    Timer {
        id: settle
        interval: 700
        onTriggered: root.probe()
    }
}
