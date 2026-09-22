pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: apps

    property var catalog: []

    function rebuild(): void {
        const src = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < src.length; i++) {
            const e = src[i]
            if (!e || e.noDisplay)
                continue
            if (!(e.name || "").length)
                continue
            if (!(e.execString || "").length && !(e.command && e.command.length))
                continue
            out.push(e)
        }
        out.sort(function (a, b) {
            return String(a.name).localeCompare(String(b.name))
        })
        apps.catalog = out
    }

    function hay(entry: var): string {
        let s = String(entry.name || "") + " " + String(entry.genericName || "") + " " + String(entry.id || "")
        const keys = entry.keywords
        if (keys && keys.length) {
            for (let i = 0; i < keys.length; i++)
                s += " " + keys[i]
        }
        return s.toLowerCase()
    }

    function score(entry: var, q: string): real {
        const name = String(entry.name || "").toLowerCase()
        const gen = String(entry.genericName || "").toLowerCase()
        const id = String(entry.id || "").toLowerCase()
        if (name.startsWith(q))
            return 400 - Math.min(80, name.length)
        if (name.indexOf(q) >= 0)
            return 280 - name.indexOf(q)
        if (gen.startsWith(q) || id.startsWith(q))
            return 180
        if (gen.indexOf(q) >= 0 || id.indexOf(q) >= 0)
            return 120
        if (apps.hay(entry).indexOf(q) >= 0)
            return 60
        return 0
    }

    function iconUrl(icon: string): string {
        const raw = String(icon || "")
        if (!raw.length)
            return ""
        if (raw.indexOf("/") === 0)
            return "file://" + raw
        const p = Quickshell.iconPath(raw, true)
        if (!p)
            return ""
        if (p.indexOf("file:") === 0 || p.indexOf("image:") === 0)
            return p
        return "file://" + p
    }

    function pack(entry: var): var {
        const name = String(entry.name || "")
        return {
            name: name,
            id: String(entry.id || ""),
            icon: apps.iconUrl(String(entry.icon || "")),
            glyph: name.length ? name.charAt(0).toUpperCase() : "?"
        }
    }

    function top(q: string, cap: int): var {
        const needle = String(q || "").trim().toLowerCase()
        if (!needle.length)
            return []
        const src = apps.catalog
        const scored = []
        for (let i = 0; i < src.length; i++) {
            const s = apps.score(src[i], needle)
            if (s > 0)
                scored.push({
                    e: src[i],
                    s: s
                })
        }
        scored.sort(function (a, b) {
            if (a.s !== b.s)
                return b.s - a.s
            return String(a.e.name).localeCompare(String(b.e.name))
        })
        const n = Math.max(0, cap)
        const out = []
        const lim = Math.min(n, scored.length)
        for (let i = 0; i < lim; i++)
            out.push(apps.pack(scored[i].e))
        return out
    }

    function launch(id: string): void {
        const e = DesktopEntries.byId(id)
        if (e)
            e.execute()
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            apps.rebuild()
        }
    }

    Component.onCompleted: apps.rebuild()
}
