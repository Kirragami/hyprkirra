pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var items: []
    property var pendingCalls: ({})
    property int swayCount: 0
    property bool subscribed: false

    readonly property int count: root.subscribed ? root.swayCount : root.items.length
    readonly property bool pending: root.count > 0

    function ingest(line: string): void {
        const t = (line || "").trim()
        if (!t.length || t.charAt(0) !== "{")
            return
        let msg
        try {
            msg = JSON.parse(t)
        } catch (e) {
            return
        }
        const kind = msg.type
        const member = msg.member || ""
        if (kind === "method_call" && member === "Notify")
            root.noteCall(msg)
        else if (kind === "method_return")
            root.noteReturn(msg)
        else if (kind === "signal" && member === "NotificationClosed")
            root.drop(root.payloadId(msg))
    }

    function noteCall(msg: var): void {
        const data = msg.payload && msg.payload.data
        if (!data || data.length < 5)
            return
        const hints = data[6] && typeof data[6] === "object" ? data[6] : {}
        const rec = {
            appName: data[0] || "",
            replacesId: Number(data[1]) || 0,
            appIcon: data[2] || "",
            summary: data[3] || "",
            body: data[4] || "",
            image: root.hintStr(hints, "image-path") || root.hintStr(hints, "image_path"),
            urgency: Number(root.hintVal(hints, "urgency")) || 1
        }
        const map = Object.assign({}, root.pendingCalls)
        map[root.callKey(msg.sender, msg.cookie)] = rec
        root.pendingCalls = map
    }

    function noteReturn(msg: var): void {
        const key = root.callKey(msg.destination, msg.reply_cookie)
        const rec = root.pendingCalls[key]
        if (!rec)
            return
        const map = Object.assign({}, root.pendingCalls)
        delete map[key]
        root.pendingCalls = map
        const payload = msg.payload
        if (!payload || payload.type !== "u")
            return
        const nid = root.payloadId(msg)
        if (!nid)
            return
        rec.id = nid
        root.upsert(rec)
    }

    function upsert(rec: var): void {
        const next = []
        const rid = rec.replacesId
        for (let i = 0; i < root.items.length; i++) {
            const cur = root.items[i]
            if (cur.id === rec.id || (rid && cur.id === rid))
                continue
            next.push(cur)
        }
        next.unshift(rec)
        root.items = next
    }

    function drop(nid: var): void {
        const id = Number(nid) || 0
        if (!id)
            return
        const next = []
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id !== id)
                next.push(root.items[i])
        }
        if (next.length !== root.items.length)
            root.items = next
    }

    function callKey(peer: var, cookie: var): string {
        return String(peer || "") + ":" + String(cookie || 0)
    }

    function payloadId(msg: var): int {
        const data = msg && msg.payload ? msg.payload.data : null
        if (data === null || data === undefined)
            return 0
        if (typeof data === "number")
            return data
        if (data.length)
            return Number(data[0]) || 0
        return 0
    }

    function hintVal(hints: var, key: string): var {
        if (!hints || !hints[key])
            return null
        const v = hints[key]
        if (v && typeof v === "object" && v.data !== undefined)
            return v.data
        return v
    }

    function hintStr(hints: var, key: string): string {
        const v = root.hintVal(hints, key)
        return typeof v === "string" ? v : ""
    }

    function readSway(line: string): void {
        const t = (line || "").trim()
        if (!t.length || t.charAt(0) !== "{")
            return
        let msg
        try {
            msg = JSON.parse(t)
        } catch (e) {
            return
        }
        root.subscribed = true
        root.swayCount = Number(msg.count) || 0
        if (root.swayCount === 0)
            root.items = []
    }

    function dismiss(n: var): void {
        const nid = n && n.id
        if (!nid)
            return
        action.exec([
            "busctl", "--user", "call",
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "CloseNotification", "u", String(nid)
        ])
        root.drop(nid)
    }

    function clearAll(): void {
        action.exec(["swaync-client", "-sw", "-C"])
        root.items = []
        root.swayCount = 0
    }

    function plain(s: string): string {
        return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
    }

    function appLabel(n: var): string {
        if (!n)
            return "UNKNOWN"
        const name = (n.appName || "").trim()
        return name.length ? name : "UNKNOWN"
    }

    function summary(n: var): string {
        if (!n)
            return "—"
        const s = root.plain(n.summary || "")
        return s.length ? s : "NO SUMMARY"
    }

    function body(n: var): string {
        if (!n)
            return ""
        return root.plain(n.body || "")
    }

    function icon(n: var): string {
        if (!n)
            return ""
        if (n.image && n.image.length)
            return n.image
        const icn = n.appIcon || ""
        if (!icn.length)
            return ""
        if (icn.indexOf("/") !== -1 || icn.indexOf(":") !== -1)
            return icn
        return Quickshell.iconPath(icn, true)
    }

    function hint(n: var): string {
        if (!n)
            return ""
        if (n.urgency === 2)
            return "CRIT"
        if (n.urgency === 0)
            return "LOW"
        return "CLR"
    }

    Process {
        id: tap
        command: [
            "busctl", "--user", "monitor", "--json=short",
            "--match", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
            "--match", "type='method_return',sender='org.freedesktop.Notifications'",
            "--match", "type='signal',interface='org.freedesktop.Notifications'"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.ingest(line)
        }
        stderr: StdioCollector {}
        onExited: tapRetry.restart()
    }

    Timer {
        id: tapRetry
        interval: 1500
        onTriggered: {
            if (!tap.running)
                tap.running = true
        }
    }

    Process {
        id: sub
        command: ["swaync-client", "-sw", "-s"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.readSway(line)
        }
        stderr: StdioCollector {}
        onExited: subRetry.restart()
    }

    Timer {
        id: subRetry
        interval: 1500
        onTriggered: {
            if (!sub.running)
                sub.running = true
        }
    }

    Process {
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: seed
        command: ["swaync-client", "-sw", "-c"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10)
                if (!isFinite(n))
                    return
                root.subscribed = true
                root.swayCount = n
            }
        }
        stderr: StdioCollector {}
    }
}
