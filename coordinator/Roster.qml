pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

QtObject {
    id: roster

    readonly property int gapMs: 300
    readonly property string rootDir: {
        const d = String(Quickshell.shellDir)
        const cut = d.lastIndexOf("/")
        return cut > 0 ? d.slice(0, cut) : d
    }

    readonly property var widgets: [
        {
            name: "bar",
            dir: "kirrabar",
            enabled: true,
            delayAfter: 700
        },
        {
            name: "noti",
            dir: "kirranoti",
            enabled: true,
            delayAfter: 200
        },
        {
            name: "holo",
            dir: "holowidget",
            enabled: true,
            delayAfter: 2200
        },
        {
            name: "geo",
            dir: "geowidget",
            enabled: true,
            delayAfter: 300
        },
        {
            name: "core",
            dir: "usagewidget",
            enabled: true,
            delayAfter: 300
        },
        {
            name: "disk",
            dir: "diskwidget",
            enabled: true,
            delayAfter: 300
        },
        {
            name: "net",
            dir: "netwidget",
            enabled: true,
            delayAfter: 300
        },
        {
            name: "util",
            dir: "kirrautil",
            enabled: true,
            delayAfter: 200
        }
    ]

    property int at: 0

    function pathOf(dir: string): string {
        return roster.rootDir + "/" + dir
    }

    function hasMore(): bool {
        const list = roster.widgets
        for (let i = roster.at; i < list.length; i++) {
            if (list[i].enabled)
                return true
        }
        return false
    }

    function boot(): void {
        roster.at = 0
        roster.step()
    }

    function step(): void {
        const list = roster.widgets
        while (roster.at < list.length && !list[roster.at].enabled)
            roster.at += 1
        if (roster.at >= list.length)
            return

        const w = list[roster.at]
        Quickshell.execDetached(["qs", "-n", "-p", roster.pathOf(w.dir)])
        roster.at += 1
        if (roster.hasMore()) {
            const wait = Number(w.delayAfter)
            gap.interval = isFinite(wait) && wait >= 0 ? wait : roster.gapMs
            gap.restart()
        }
    }

    property Timer gap: Timer {
        interval: roster.gapMs
        repeat: false
        onTriggered: roster.step()
    }

    property Timer keep: Timer {
        interval: 3600000
        running: true
        repeat: true
    }

    Component.onCompleted: roster.boot()
}
