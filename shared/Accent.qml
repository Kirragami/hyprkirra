pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: accent

    readonly property string fallback: "#ff7a18"
    readonly property string path: `${Quickshell.env("HOME")}/.config/hypr/custom.lua`
    readonly property string hex: accent.pick(accent.blob)
    readonly property color warn: accent.hex
    readonly property string rgb: {
        const c = accent.warn
        return Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255)
    }

    property string blob: ""
    property string lastPushed: ""

    function pick(t: string): string {
        const lines = (t || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].replace(/--.*$/, "")
            const m = line.match(/\baccent\s*=\s*"#?([0-9a-fA-F]{6})"/)
            if (m)
                return "#" + m[1].toLowerCase()
        }
        return accent.fallback
    }

    function pushHypr(): void {
        const h = accent.hex.replace("#", "")
        if (h === accent.lastPushed)
            return
        accent.lastPushed = h
        const rgba = "rgba(" + h + "ff)"
        Quickshell.execDetached(["hyprctl", "keyword", "plugin:kirracorners:col.line", rgba])
        Quickshell.execDetached(["hyprctl", "keyword", "plugin:kirracorners:col.dim", rgba])
    }

    onHexChanged: accent.pushHypr()

    FileView {
        path: accent.path
        preload: true
        watchChanges: true
        onLoaded: accent.blob = text()
        onFileChanged: reload()
        onLoadFailed: accent.blob = ""
    }
}
