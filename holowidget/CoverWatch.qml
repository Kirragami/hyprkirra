pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: cover

    property var screen: null
    property bool paused: false
    property bool probePending: false
    property bool holdPause: false
    property bool exitLock: false
    property int probeGen: 0
    property int applyGen: 0

    readonly property var hyprWs: {
        const mon = cover.screen ? Hyprland.monitorFor(cover.screen) : null
        return (mon && mon.activeWorkspace) || Hyprland.focusedWorkspace
    }

    Component.onCompleted: cover.probeCover()
    onScreenChanged: cover.probeCover()

    function pause(): void {
        if (cover.paused)
            return
        cover.paused = true
    }

    function resume(): void {
        if (!cover.paused)
            return
        cover.paused = false
    }

    function parseFullscreenFlag(data: string): int {
        const t = String(data || "").trim()
        if (!t.length)
            return -1
        const bits = t.split(",")
        const last = bits[bits.length - 1].trim()
        if (last === "0" || last === "false")
            return 0
        if (last === "1" || last === "true")
            return 1
        return -1
    }

    function onFullscreenFlag(on: bool): void {
        cover.probeGen += 1
        if (on) {
            cover.exitLock = false
            cover.holdPause = true
            cover.probePending = false
            cover.pause()
            Hyprland.refreshWorkspaces()
            return
        }
        cover.holdPause = false
        cover.exitLock = true
        cover.probePending = true
        cover.resume()
        Hyprland.refreshWorkspaces()
        coverKick.restart()
    }

    function qsThinksCovered(): bool {
        const ws = cover.hyprWs
        return !!(ws && ws.hasFullscreen)
    }

    function syncCover(): void {
        if (cover.probePending)
            return
        if (cover.qsThinksCovered()) {
            if (!cover.exitLock)
                cover.pause()
            return
        }
        cover.exitLock = false
        cover.holdPause = false
        cover.resume()
    }

    function probeCover(): void {
        cover.probePending = true
        cover.probeGen += 1
        coverKick.restart()
    }

    function applyWorkspaceJson(raw: string): void {
        if (cover.applyGen !== cover.probeGen)
            return
        cover.probePending = false
        let list
        try {
            list = JSON.parse(raw)
        } catch (e) {
            cover.syncCover()
            return
        }
        if (!Array.isArray(list)) {
            cover.syncCover()
            return
        }
        const mon = cover.screen ? Hyprland.monitorFor(cover.screen) : null
        const monName = mon && mon.name ? String(mon.name) : ""
        const wsId = mon && mon.activeWorkspace ? Number(mon.activeWorkspace.id) : NaN
        let covered = false
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            if (!w || !w.hasfullscreen)
                continue
            if (monName.length && String(w.monitor) !== monName)
                continue
            if (isFinite(wsId) && Number(w.id) !== wsId)
                continue
            covered = true
            break
        }
        if (covered) {
            if (cover.exitLock) {
                cover.resume()
                return
            }
            cover.pause()
            return
        }
        cover.exitLock = false
        cover.holdPause = false
        cover.resume()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            const n = event.name
            if (n === "fullscreen" || n === "fullscreenv2") {
                const flag = cover.parseFullscreenFlag(event.data)
                if (flag === 0 || flag === 1) {
                    cover.onFullscreenFlag(flag === 1)
                    return
                }
            }
            if (n === "fullscreen" || n === "fullscreenv2" || n === "workspace" || n === "workspacev2"
                    || n === "focusedmon" || n === "fullscreenstate" || n === "fullscreenstatchange") {
                Hyprland.refreshWorkspaces()
                cover.probeCover()
            }
        }
        function onFocusedWorkspaceChanged(): void {
            cover.probeCover()
        }
        function onFocusedMonitorChanged(): void {
            cover.probeCover()
        }
    }

    Connections {
        target: cover.hyprWs
        function onHasFullscreenChanged(): void {
            if (!cover.probePending)
                cover.probeCover()
        }
    }

    Process {
        id: fsProbe
        command: ["hyprctl", "workspaces", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: cover.applyWorkspaceJson(text)
        }
        stderr: StdioCollector {}
        onExited: {
            if (fsProbe.exitCode !== 0 && cover.probePending) {
                cover.probePending = false
                cover.syncCover()
            }
        }
    }

    Timer {
        id: coverKick
        interval: 50
        repeat: false
        onTriggered: {
            cover.applyGen = cover.probeGen
            if (fsProbe.running)
                fsProbe.running = false
            fsProbe.running = true
        }
    }
}
