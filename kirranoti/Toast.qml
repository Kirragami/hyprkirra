pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "svc"

Item {
    id: toast

    property var notif: null
    property var pending: null
    property real boot: 0
    property real swap: 1
    property bool leaving: false

    readonly property int tileS: 76
    readonly property int boxW: 400
    readonly property int cardW: toast.tileS + toast.boxW
    readonly property int cardH: toast.tileS

    readonly property string appNameRaw: toast.notif ? String(toast.notif.appName || toast.notif.desktopEntry || "") : ""
    readonly property string sumRaw: toast.notif ? String(toast.notif.summary || "") : ""
    readonly property string bodyRaw: toast.notif ? String(toast.notif.body || "") : ""
    readonly property string appLabel: {
        const app = toast.clip(toast.plain(toast.appNameRaw), 22)
        return app.length ? app.toUpperCase() : "SYS"
    }
    readonly property string sumText: toast.packTitle()
    readonly property string bodyText: toast.packBody()
    readonly property string iconSrc: toast.iconOf(toast.notif)
    readonly property real slide: toast.gate(0.80, 0.94)
    readonly property real iconOn: toast.gate(0.60, 0.78)
    readonly property real copyOn: toast.gate(0.82, 0.94)
    readonly property real tileW: toast.morphW()
    readonly property real tileH: toast.morphH()
    readonly property real tileX: (toast.boxW + (toast.tileS - toast.tileW) * 0.5) * (1 - toast.slide)
    readonly property real tileY: (toast.tileS - toast.tileH) * 0.5

    signal done()
    signal hide()
    signal swapCommitted(var n)

    width: toast.cardW
    height: toast.cardH
    opacity: toast.boot > 0.001 ? 1 : 0

    function gate(a: real, b: real): real {
        if (toast.boot >= 1)
            return 1
        return Math.max(0, Math.min(1, (toast.boot - a) / Math.max(0.001, b - a)))
    }

    function morphW(): real {
        const dot = 5
        if (toast.boot < 0.16)
            return Math.max(0.5, dot * toast.gate(0, 0.16))
        return 5 + (toast.tileS - 5) * toast.gate(0.16, 0.42)
    }

    function morphH(): real {
        const thin = 5
        if (toast.boot < 0.42)
            return toast.boot < 0.16 ? Math.max(0.5, thin * toast.gate(0, 0.16)) : thin
        return thin + (toast.tileS - thin) * toast.gate(0.42, 0.58)
    }

    function plain(s: string): string {
        return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
    }

    function isOrigin(s: string): bool {
        const t = String(s || "").trim()
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
        if (toast.isOrigin(head))
            return lines.slice(1)
        if (toast.isBrowser(app) && head.length <= 36 && !/[.!?]$/.test(head))
            return lines.slice(1)
        return lines
    }

    function packTitle(): string {
        const app = toast.appNameRaw
        let title = toast.plain(toast.sumRaw)
        const lines = toast.peel(toast.bodyLines(toast.bodyRaw), app)
        const rest = toast.plain(lines.join(" "))
        if (toast.isOrigin(title) && rest.length)
            title = rest
        if (!title.length)
            title = rest.length ? rest : toast.appLabel
        return toast.clip(title, 52)
    }

    function packBody(): string {
        const app = toast.appNameRaw
        let title = toast.plain(toast.sumRaw)
        const lines = toast.peel(toast.bodyLines(toast.bodyRaw), app)
        let rest = toast.plain(lines.join(" "))
        if (toast.isOrigin(title) && rest.length)
            return ""
        if (!title.length)
            return ""
        if (rest === title)
            return ""
        if (rest.indexOf(title) === 0)
            rest = rest.slice(title.length).replace(/^[\s\-–—:]+/, "")
        rest = rest.replace(/^(https?:\/\/)?[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(:\d+)?\s+/i, "")
        return rest.length ? toast.clip(rest, 120) : ""
    }

    function clip(s: string, n: int): string {
        const t = String(s || "")
        if (t.length <= n)
            return t
        let cut = t.slice(0, n)
        const sp = cut.lastIndexOf(" ")
        if (sp >= Math.floor(n * 0.55))
            cut = cut.slice(0, sp)
        return cut.replace(/[\s.,;:!?]+$/, "") + "..."
    }

    function iconOf(n: var): string {
        if (!n)
            return ""
        if (n.image && String(n.image).length)
            return n.image
        const icn = String(n.appIcon || "")
        if (!icn.length)
            return ""
        if (icn.indexOf("/") !== -1 || icn.indexOf(":") !== -1)
            return icn
        return Quickshell.iconPath(icn, true)
    }

    function appKey(n: var): string {
        if (!n)
            return ""
        return String(n.desktopEntry || n.appName || "").toLowerCase()
    }

    function titleKey(n: var): string {
        if (!n)
            return ""
        return String(n.summary || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().toLowerCase()
    }

    function isCli(n: var): bool {
        const a = toast.appKey(n)
        return a === "" || a === "notify-send" || a === "notify_send" || a === "libnotify" || a === "gdbus"
    }

    function matches(n: var): bool {
        const cur = toast.pending || toast.notif
        if (!cur || !n)
            return false
        if (toast.isCli(cur) || toast.isCli(n))
            return false
        const title = toast.titleKey(n)
        if (!title.length || toast.titleKey(cur) !== title)
            return false
        return toast.appKey(cur) === toast.appKey(n)
    }

    function replaceWith(n: var): void {
        if (!n)
            return
        n.tracked = true
        toast.pending = n
        if (toast.leaving) {
            toast.leaving = false
            outAnim.stop()
            inAnim.duration = Math.max(1, Math.round(1100 * (1 - toast.boot)))
            inAnim.restart()
        }
        hold.stop()
        swapAnim.restart()
    }

    function commitPending(): void {
        const next = toast.pending
        const prev = toast.notif
        if (!next)
            return
        toast.pending = null
        toast.swapCommitted(next)
        if (prev && prev !== next)
            prev.tracked = false
    }

    function dismiss(): void {
        toast.leave()
    }

    function leave(): void {
        if (toast.leaving)
            return
        toast.leaving = true
        hold.stop()
        inAnim.stop()
        outAnim.duration = Math.max(1, Math.round(1100 * toast.boot))
        outAnim.restart()
    }

    function holdMs(): int {
        const t = toast.notif ? toast.notif.expireTimeout : 0
        if (t > 0 && t < 180)
            return Math.round(Math.max(1.6, Math.min(12, t)) * 1000)
        if (t >= 180)
            return Math.round(Math.min(12000, t))
        return 5200
    }

    Component.onCompleted: {
        inAnim.duration = Math.max(1, Math.round(1100 * (1 - toast.boot)))
        inAnim.restart()
    }

    Connections {
        target: toast.notif
        ignoreUnknownSignals: true
        function onClosed(): void {
            toast.leave()
        }
    }

    NumberAnimation {
        id: inAnim
        target: toast
        property: "boot"
        to: 1
        duration: 1100
        easing.type: Easing.Linear
        onStopped: {
            if (toast.boot >= 1 && !toast.leaving) {
                hold.interval = toast.holdMs()
                hold.restart()
            }
        }
    }

    NumberAnimation {
        id: outAnim
        target: toast
        property: "boot"
        to: 0
        duration: 1100
        easing.type: Easing.Linear
        onStopped: {
            if (toast.boot <= 0.001)
                toast.done()
        }
    }

    Timer {
        id: hold
        onTriggered: toast.hide()
    }

    SequentialAnimation {
        id: swapAnim
        NumberAnimation {
            target: toast
            property: "swap"
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: toast.commitPending()
        }
        NumberAnimation {
            target: toast
            property: "swap"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                if (toast.boot >= 1 && !toast.leaving) {
                    hold.interval = toast.holdMs()
                    hold.restart()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toast.dismiss()
    }

    Rectangle {
        id: tile
        x: toast.tileX
        y: toast.tileY
        width: toast.tileW
        height: toast.tileH
        color: "#ffffff"
        clip: true

        Image {
            id: glyph
            visible: glyph.status === Image.Ready
            source: toast.iconSrc
            width: 36
            height: 36
            sourceSize.width: 36
            sourceSize.height: 36
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
            opacity: toast.iconOn * toast.swap
            asynchronous: true
        }

        Text {
            visible: glyph.status !== Image.Ready
            text: "\uf0e0"
            color: "#070707"
            font.family: Theme.fontMono
            font.pixelSize: 26
            anchors.centerIn: parent
            opacity: toast.iconOn * toast.swap
        }
    }

    Item {
        id: box
        x: toast.tileX + toast.tileW
        y: 0
        width: toast.boxW * toast.slide
        height: toast.tileS
        clip: true

            Rectangle {
                width: toast.boxW
                height: toast.tileS
                color: "#070707"

                Column {
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 2
                    opacity: toast.copyOn * toast.swap

                    Text {
                        width: parent.width
                        text: toast.sumText
                        color: "#f3f3f3"
                        font.family: Theme.fontHud
                        font.pixelSize: 16
                        font.letterSpacing: 0.2
                        font.bold: true
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        textFormat: Text.PlainText
                    }

                    Text {
                        visible: toast.bodyText.length > 0
                        width: parent.width
                        height: 34
                        text: toast.bodyText
                        color: "#b4b4b4"
                        font.family: Theme.fontHud
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        clip: true
                        textFormat: Text.PlainText
                    }
                }
        }
    }
}
