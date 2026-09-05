pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    property int bars: 36
    property var levels: root.flat(0)

    function flat(v: real): var {
        const a = []
        for (let i = 0; i < root.bars; i++)
            a.push(v)
        return a
    }

    function read(line: string): void {
        const t = line.trim()
        if (!t.length)
            return
        const parts = t.split(";")
        if (parts.length < 4)
            return
        const n = Math.min(root.bars, parts.length)
        const out = []
        for (let i = 0; i < n; i++) {
            const v = Number(parts[i])
            out.push(isFinite(v) ? Math.max(0, Math.min(1, v / 100)) : 0)
        }
        while (out.length < root.bars)
            out.push(0)
        root.levels = out
    }

    onActiveChanged: {
        if (!root.active)
            root.levels = root.flat(0)
    }

    Process {
        id: probe
        command: ["python3", "-u", Quickshell.shellPath("fui/spectrum.py"), "" + root.bars]
        running: root.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.read(line)
        }
        stderr: StdioCollector {}
        onExited: {
            if (root.active)
                retry.restart()
        }
    }

    Timer {
        id: retry
        interval: 1500
        onTriggered: {
            if (root.active && !probe.running)
                probe.running = true
        }
    }
}
