pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool wifiOn: true
    property bool scanning: false
    property bool wired: false
    property string activeSsid: ""
    property string statusLine: "SCAN"
    property string lastError: ""
    property bool needsPassword: false
    property string pendingSsid: ""
    property var networks: []

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

    function refresh(rescan: bool): void {
        root.scanning = true
        root.lastError = ""
        const mode = rescan ? "yes" : "auto"
        probe.exec([
            "sh", "-c",
            "echo RADIO; nmcli -t -f WIFI radio; echo LIST; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan "
            + mode + "; echo ACTIVE; nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active"
        ])
    }

    function toggleRadio(): void {
        action.exec(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
    }

    function connectSsid(ssid: string, password: string): void {
        root.pendingSsid = ssid
        root.lastError = ""
        if (password && password.length)
            action.exec(["nmcli", "-w", "15", "device", "wifi", "connect", ssid, "password", password])
        else
            action.exec(["nmcli", "-w", "15", "device", "wifi", "connect", ssid])
    }

    function parse(raw: string): void {
        const lines = raw.split("\n")
        let section = ""
        const nets = []
        let radio = "enabled"
        let wiredUp = false
        let ssid = ""
        const seen = {}

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line === "RADIO" || line === "LIST" || line === "ACTIVE") {
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
                if (!name || seen[name])
                    continue
                seen[name] = true
                const inUse = (p[0] || "").indexOf("*") !== -1
                const signal = Number(p[2]) || 0
                const sec = (p[3] || "")
                if (inUse)
                    ssid = name
                nets.push({
                    ssid: name,
                    signal: signal,
                    secure: sec.length > 0 && sec !== "--",
                    inUse: inUse
                })
            } else if (section === "ACTIVE") {
                const p = root.splitNm(line)
                const type = (p[1] || "").toLowerCase()
                const state = (p[3] || "").toLowerCase()
                if (type.indexOf("ethernet") !== -1 && state.indexOf("activ") !== -1)
                    wiredUp = true
                if (type.indexOf("wireless") !== -1 && !ssid)
                    ssid = p[0] || ""
            }
        }

        nets.sort((a, b) => {
            if (a.inUse !== b.inUse)
                return a.inUse ? -1 : 1
            return b.signal - a.signal
        })

        root.wifiOn = radio !== "disabled"
        root.wired = wiredUp
        root.activeSsid = ssid
        root.networks = nets
        root.scanning = false

        if (wiredUp && ssid)
            root.statusLine = "WIRED + WIFI"
        else if (wiredUp)
            root.statusLine = "WIRED"
        else if (ssid)
            root.statusLine = ssid
        else if (!root.wifiOn)
            root.statusLine = "RADIO OFF"
        else
            root.statusLine = "NO LINK"
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
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.toLowerCase()
                if (t.indexOf("secret") !== -1 || t.indexOf("password") !== -1) {
                    root.needsPassword = true
                    root.lastError = "KEY REQUIRED"
                } else if (text.trim().length) {
                    root.lastError = text.trim().split("\n")[0]
                    root.needsPassword = false
                }
            }
        }
        onExited: code => {
            if (code === 0) {
                root.needsPassword = false
                root.pendingSsid = ""
                root.lastError = ""
            }
            root.refresh(false)
        }
    }

    Component.onCompleted: root.refresh(false)
}
