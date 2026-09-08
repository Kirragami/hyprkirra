pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool wifiOn: true
    property bool scanning: false
    property bool connecting: false
    property bool wired: false
    property string activeSsid: ""
    property string statusLine: "SCAN"
    property string lastError: ""
    property bool needsPassword: false
    property string pendingSsid: ""
    property var networks: []
    property var savedBySsid: ({})

    property bool joinCancel: false
    property string joinMode: ""

    function splitNm(line: string): var {
        const out = []
        let cur = ""
        let esc = false
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (esc) {
                cur += ch
                esc = false
                continue
            }
            if (ch === "\\") {
                esc = true
                continue
            }
            if (ch === ":") {
                out.push(cur)
                cur = ""
                continue
            }
            cur += ch
        }
        out.push(cur)
        return out
    }

    function savedName(ssid: string): string {
        const map = root.savedBySsid
        if (!ssid || !map)
            return ""
        return map[ssid] || ""
    }

    function syncStatus(): void {
        if (root.connecting)
            root.statusLine = "LINKING"
        else if (root.wired && root.activeSsid)
            root.statusLine = "WIRED + WIFI"
        else if (root.wired)
            root.statusLine = "WIRED"
        else if (root.activeSsid)
            root.statusLine = root.activeSsid
        else if (!root.wifiOn)
            root.statusLine = "RADIO OFF"
        else
            root.statusLine = "NO LINK"
    }

    function refresh(rescan: bool): void {
        if (root.connecting)
            return
        root.scanning = true
        const mode = rescan ? "yes" : "auto"
        probe.exec([
            "sh", "-c",
            "echo RADIO; nmcli -t -f WIFI radio; echo LIST; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan "
            + mode + "; echo ACTIVE; nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active"
            + "; echo SAVED; nmcli -t -f NAME,UUID,TYPE connection show; echo SSIDS; "
            + "nmcli -t -f UUID,TYPE connection show | while IFS= read -r line; do "
            + "[ -z \"$line\" ] && continue; typ=${line##*:}; uuid=${line%:*}; "
            + "case \"$typ\" in 802-11-wireless|wifi) "
            + "ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid \"$uuid\" 2>/dev/null || true); "
            + "printf '%s:%s\\n' \"$uuid\" \"$ssid\";; esac; done"
        ])
    }

    function stopJoin(): void {
        if (join.running) {
            root.joinCancel = true
            join.running = false
        }
        root.connecting = false
        root.syncStatus()
    }

    function toggleRadio(): void {
        root.stopJoin()
        root.lastError = ""
        root.needsPassword = false
        action.exec(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
    }

    function activate(net: var): void {
        if (!net || !root.wifiOn || net.inUse || root.connecting)
            return
        const ssid = net.ssid || ""
        if (!ssid)
            return
        root.pendingSsid = ssid
        root.lastError = ""
        if (net.secure && !net.known) {
            root.needsPassword = true
            return
        }
        root.connectSsid(ssid, "")
    }

    function connectSsid(ssid: string, password: string): void {
        if (!ssid || root.connecting)
            return
        root.pendingSsid = ssid
        root.lastError = ""
        root.needsPassword = false
        root.connecting = true
        root.syncStatus()

        const name = root.savedName(ssid)
        if (password && password.length) {
            root.joinMode = "psk"
            join.exec(["nmcli", "-w", "20", "device", "wifi", "connect", ssid, "password", password])
        } else if (name.length) {
            root.joinMode = "up"
            join.exec(["nmcli", "-w", "20", "connection", "up", name])
        } else {
            root.joinMode = "wifi"
            join.exec(["nmcli", "-w", "20", "device", "wifi", "connect", ssid])
        }
    }

    function wantsKey(blob: string): bool {
        const low = blob.toLowerCase()
        return low.indexOf("secret") !== -1 || low.indexOf("password") !== -1 || low.indexOf("802-11-wireless-security") !== -1
    }

    function finishJoin(code: int, outText: string, errText: string): void {
        if (root.joinCancel) {
            root.joinCancel = false
            return
        }
        const blob = ((errText || "") + "\n" + (outText || "")).trim()
        if (code !== 0 && root.joinMode === "up" && root.pendingSsid.length && !root.wantsKey(blob)) {
            root.joinMode = "wifi"
            joinKick.restart()
            return
        }
        root.connecting = false
        root.joinMode = ""
        if (code === 0) {
            root.needsPassword = false
            root.pendingSsid = ""
            root.lastError = ""
        } else if (root.wantsKey(blob)) {
            root.needsPassword = true
            root.lastError = "KEY REQUIRED"
        } else {
            root.needsPassword = false
            const line = blob.split("\n")[0].trim()
            root.lastError = line.length ? line.replace(/^error:\s*/i, "") : "LINK FAILED"
        }
        root.refresh(false)
        root.syncStatus()
    }

    function parse(raw: string): void {
        const lines = raw.split("\n")
        let section = ""
        const nets = []
        const byName = {}
        let radio = "enabled"
        let wiredUp = false
        let ssid = ""
        const uuidToName = {}
        const saved = {}

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line === "RADIO" || line === "LIST" || line === "ACTIVE" || line === "SAVED" || line === "SSIDS") {
                section = line
                continue
            }
            if (!line)
                continue

            if (section === "RADIO") {
                radio = line.toLowerCase()
            } else if (section === "LIST") {
                const p = root.splitNm(line)
                const name = (p[1] || "").trim()
                if (!name)
                    continue
                const inUse = (p[0] || "").indexOf("*") !== -1
                const signal = Number(p[2]) || 0
                const sec = (p[3] || "")
                const secure = sec.length > 0 && sec !== "--"
                if (inUse)
                    ssid = name
                const prev = byName[name]
                if (prev) {
                    if (inUse)
                        prev.inUse = true
                    if (signal > prev.signal)
                        prev.signal = signal
                    if (secure)
                        prev.secure = true
                    continue
                }
                const rec = {
                    ssid: name,
                    signal: signal,
                    secure: secure,
                    inUse: inUse,
                    known: false
                }
                byName[name] = rec
                nets.push(rec)
            } else if (section === "ACTIVE") {
                const p = root.splitNm(line)
                const type = (p[1] || "").toLowerCase()
                const state = (p[3] || "").toLowerCase()
                if (type.indexOf("ethernet") !== -1 && state.indexOf("activ") !== -1)
                    wiredUp = true
                if ((type.indexOf("wireless") !== -1 || type.indexOf("wifi") !== -1) && !ssid)
                    ssid = p[0] || ""
            } else if (section === "SAVED") {
                const p = root.splitNm(line)
                const name = (p[0] || "").trim()
                const uuid = (p[1] || "").trim()
                const type = (p[2] || "").toLowerCase()
                if (!name)
                    continue
                if (type.indexOf("wireless") === -1 && type.indexOf("wifi") === -1)
                    continue
                uuidToName[uuid] = name
                saved[name] = name
            } else if (section === "SSIDS") {
                const cut = line.indexOf(":")
                if (cut < 1)
                    continue
                const uuid = line.slice(0, cut).trim()
                const wifiSsid = line.slice(cut + 1).trim()
                const name = uuidToName[uuid]
                if (wifiSsid && name)
                    saved[wifiSsid] = name
            }
        }

        for (let n = 0; n < nets.length; n++)
            nets[n].known = !!saved[nets[n].ssid]

        nets.sort((a, b) => {
            if (a.inUse !== b.inUse)
                return a.inUse ? -1 : 1
            return b.signal - a.signal
        })

        root.wifiOn = radio !== "disabled"
        root.wired = wiredUp
        root.activeSsid = ssid
        root.savedBySsid = saved
        root.networks = nets
        root.scanning = false
        root.syncStatus()
    }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: code => {
            if (code !== 0)
                root.scanning = false
        }
    }

    Process {
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh(false)
    }

    Process {
        id: join
        stdout: StdioCollector { id: joinOut }
        stderr: StdioCollector { id: joinErr }
        onExited: code => root.finishJoin(code, joinOut.text, joinErr.text)
    }

    Timer {
        id: joinKick
        interval: 1
        repeat: false
        onTriggered: {
            if (!root.connecting || !root.pendingSsid.length)
                return
            join.exec(["nmcli", "-w", "20", "device", "wifi", "connect", root.pendingSsid])
        }
    }

    Component.onCompleted: root.refresh(false)
}
