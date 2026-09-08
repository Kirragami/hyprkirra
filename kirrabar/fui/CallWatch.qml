pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    property bool connected: false
    property string appName: ""
    property var playNode: null
    property real peak: 0
    property bool rawLive: false
    property int gen: 0

    readonly property var allow: [
        "telegram", "discord", "vesktop", "webcord", "armcord", "legcord",
        "slack", "zoom", "skype", "teams", "chromium", "google-chrome",
        "chrome", "brave", "firefox", "vivaldi", "signal", "whatsapp",
        "element", "jitsi", "caprine", "mattermost", "msedge",
        "microsoft-edge", "opera", "floorp"
    ]

    function blob(node: var): string {
        if (!node)
            return ""
        const p = node.ready ? (node.properties || {}) : {}
        return [
            p["application.name"],
            p["application.process.binary"],
            p["application.id"],
            p["media.name"],
            p["media.role"],
            p["node.name"],
            node.nickname,
            node.description,
            node.name
        ].map(v => (v || "").toString().toLowerCase()).join(" ")
    }

    function isComms(node: var): bool {
        if (!node || !node.ready)
            return false
        const role = String((node.properties || {})["media.role"] || "").toLowerCase()
        return role === "communication" || role === "phone"
    }

    function isCallApp(node: var): bool {
        const b = root.blob(node)
        if (!b.length)
            return false
        const keys = root.allow
        for (let i = 0; i < keys.length; i++) {
            if (b.indexOf(keys[i]) !== -1)
                return true
        }
        return false
    }

    function mediaClass(node: var): string {
        if (!node || !node.ready)
            return ""
        return String((node.properties || {})["media.class"] || "")
    }

    function isCapture(node: var): bool {
        return node && node.isStream && root.mediaClass(node).indexOf("Stream/Input/Audio") !== -1
    }

    function isPlayback(node: var): bool {
        return node && node.isStream && root.mediaClass(node).indexOf("Stream/Output/Audio") !== -1
    }

    function voiceMedia(node: var): bool {
        if (!node || !node.ready)
            return false
        const m = String((node.properties || {})["media.name"] || "").toLowerCase()
        return /voice chat|voice call|incoming call|webrtc|audio call|video call/.test(m)
    }

    function appLabel(node: var): string {
        if (!node)
            return "COM"
        const p = node.ready ? (node.properties || {}) : {}
        const name = p["application.name"] || node.nickname || node.description || "COM"
        return String(name).toUpperCase()
    }

    function sameApp(a: var, b: var): bool {
        if (!a || !b || !a.ready || !b.ready)
            return false
        const pa = a.properties || {}
        const pb = b.properties || {}
        const na = (pa["application.name"] || "").toString()
        const nb = (pb["application.name"] || "").toString()
        return na.length > 0 && na === nb
    }

    function scan(): void {
        const list = Pipewire.nodes.values
        let capture = null
        let play = null
        let voiceOut = null

        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (!n || !n.isStream)
                continue
            if (root.isCapture(n) && (root.isCallApp(n) || root.isComms(n)))
                capture = n
            if (root.isPlayback(n) && root.isCallApp(n)) {
                if (root.voiceMedia(n) || root.isComms(n))
                    voiceOut = n
                play = n
            }
        }

        const live = capture !== null || voiceOut !== null
        const lead = capture || voiceOut
        let meter = null
        if (lead) {
            if (play && root.sameApp(lead, play))
                meter = play
            else if (voiceOut)
                meter = voiceOut
            else
                meter = lead
        }

        root.rawLive = live
        root.appName = live ? root.appLabel(lead) : ""
        if (root.playNode !== meter)
            root.playNode = meter
        if (!live)
            root.peak = 0
    }

    onRawLiveChanged: {
        if (root.rawLive) {
            drop.stop()
            if (!root.connected)
                rise.restart()
        } else {
            rise.stop()
            if (root.connected)
                drop.restart()
            else
                root.playNode = null
        }
    }

    Timer {
        id: rise
        interval: 140
        onTriggered: root.connected = true
    }

    Timer {
        id: drop
        interval: 180
        onTriggered: {
            root.connected = false
            root.playNode = null
            root.peak = 0
        }
    }

    Timer {
        interval: 350
        running: true
        repeat: true
        onTriggered: root.scan()
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index): void {
            root.gen++
            root.scan()
        }
        function onObjectRemovedPost(object, index): void {
            root.gen++
            root.scan()
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged(): void { root.scan() }
        function onDefaultAudioSourceChanged(): void { root.scan() }
    }

    PwObjectTracker {
        objects: {
            const _ = root.gen
            const out = []
            const list = Pipewire.nodes.values
            for (let i = 0; i < list.length; i++) {
                const n = list[i]
                if (n && n.isStream)
                    out.push(n)
            }
            if (Pipewire.defaultAudioSink)
                out.push(Pipewire.defaultAudioSink)
            if (Pipewire.defaultAudioSource)
                out.push(Pipewire.defaultAudioSource)
            return out
        }
    }

    PwNodePeakMonitor {
        id: peaks
        node: root.playNode
        enabled: root.connected && root.playNode !== null
        onPeakChanged: root.peak = root.peak * 0.48 + peaks.peak * 0.52
    }

    Component.onCompleted: root.scan()
}
