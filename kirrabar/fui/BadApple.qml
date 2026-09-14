pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    property bool playing: false
    property real position: 0
    property bool tape: false
    property string frame: ""
    property real start: 0
    property real lastPos: 0
    property int cols: 220
    property int rows: 32
    readonly property bool ready: root.tape

    function read(line: string): void {
        const t = line.trim()
        if (!t.length)
            return
        if (t.startsWith("OK")) {
            root.tape = true
            const p = t.split(/\s+/)
            if (p.length >= 3) {
                const c = Number(p[1])
                const r = Number(p[2])
                if (c > 0)
                    root.cols = c
                if (r > 0)
                    root.rows = r
            }
            return
        }
        if (t.startsWith("ERR")) {
            root.tape = false
            return
        }
        if (t.startsWith("F "))
            root.frame = t.slice(2)
    }

    function go(pos: real): void {
        root.start = Math.max(0, pos || 0)
        root.lastPos = root.start
        play.running = false
        kick.restart()
    }

    onActiveChanged: {
        if (!root.active) {
            kick.stop()
            play.running = false
            root.frame = ""
            return
        }
        if (root.playing && root.tape)
            root.go(root.position)
    }

    onPlayingChanged: {
        if (!root.active || !root.tape)
            return
        if (root.playing)
            root.go(root.position)
        else {
            kick.stop()
            play.running = false
        }
    }

    onTapeChanged: {
        if (root.tape && root.active && root.playing && !play.running)
            root.go(root.position)
    }

    Process {
        id: probe
        command: ["python3", "-u", Quickshell.shellPath("fui/badapple.py"), "--probe"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.read(line)
        }
        stderr: StdioCollector {}
    }

    Process {
        id: play
        command: [
            "python3",
            "-u",
            Quickshell.shellPath("fui/badapple.py"),
            root.start.toFixed(3)
        ]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.read(line)
        }
        stderr: StdioCollector {}
        onExited: {
            if (root.active && root.playing && root.tape)
                retry.restart()
        }
    }

    Timer {
        id: kick
        interval: 16
        onTriggered: {
            if (root.active && root.playing && root.tape && !play.running)
                play.running = true
        }
    }

    Timer {
        id: retry
        interval: 800
        onTriggered: {
            if (root.active && root.playing && root.tape && !play.running)
                root.go(root.position)
        }
    }

    Timer {
        interval: 400
        running: root.active && root.playing
        repeat: true
        onTriggered: {
            const pos = root.position
            if (Math.abs(pos - root.lastPos) > 1.2)
                root.go(pos)
            else
                root.lastPos = pos
        }
    }
}
