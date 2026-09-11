pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var items: []
    property var pendingCalls: ({})

    readonly property int count: root.items.length
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
        const list = root.items.slice()
        for (let i = 0; i < list.length; i++)
            root.dismiss(list[i])
        root.items = []
    }

    function plain(s: string): string {
        return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
    }

    function isOrigin(s: string): bool {
        const t = (s || "").trim()
        if (!t.length)
            return false
        if (/^https?:\/\//i.test(t))
            return true
        if (/^[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+(:\d+)?$/i.test(t))
            return true
        if (/^(localhost|(\d{1,3}\.){3}\d{1,3})(:\d+)?$/i.test(t))
            return true
        return false
    }

    function isBrowser(app: string): bool {
        return /\b(chrome|chromium|firefox|brave|edg|vivaldi|opera|webkit)\b/i.test(app || "")
    }

    function bodyLines(s: string): var {
        return String(s || "").replace(/<[^>]+>/g, " ").replace(/\r/g, "").split(/\n+/).map(function (l) {
            return l.replace(/\s+/g, " ").trim()
        }).filter(function (l) {
            return l.length > 0
        })
    }

    function peel(lines: var, app: string): var {
        if (!lines || lines.length < 2)
            return lines
        const head = lines[0]
        if (root.isOrigin(head))
            return lines.slice(1)
        if (root.isBrowser(app) && head.length <= 36 && !/[.!?]$/.test(head))
            return lines.slice(1)
        return lines
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
        const app = n.appName || ""
        let title = root.plain(n.summary || "")
        const rest = root.plain(root.peel(root.bodyLines(n.body || ""), app).join(" "))
        if (root.isOrigin(title) && rest.length)
            title = rest
        if (!title.length)
            title = rest.length ? rest : "NO SUMMARY"
        return root.clip(title, 42)
    }

    function body(n: var): string {
        if (!n)
            return ""
        const app = n.appName || ""
        const title = root.plain(n.summary || "")
        let rest = root.plain(root.peel(root.bodyLines(n.body || ""), app).join(" "))
        if (root.isOrigin(title) && rest.length)
            return ""
        if (!title.length || rest === title)
            return ""
        if (rest.indexOf(title) === 0)
            rest = rest.slice(title.length).replace(/^[\s\-–—:]+/, "")
        rest = rest.replace(/^(https?:\/\/)?[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(:\d+)?\s+/i, "")
        return rest.length ? root.clip(rest, 90) : ""
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
        return n ? "CLR" : ""
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
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
