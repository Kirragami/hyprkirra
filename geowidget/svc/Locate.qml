pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string iso2: ""
    property string tzName: ""
    property string tzOff: ""
    property string ip: ""
    property string localIp: ""
    property string city: ""
    property string region: ""
    property string country: ""
    property string isp: ""
    property string kind: ""
    property real lat: 0
    property real lon: 0
    property bool online: false
    property bool hasCoords: false
    property bool hasFix: false
    property string status: "PROBE"

    readonly property var tzMap: ({
        "Asia/Yangon": "MM",
        "Asia/Rangoon": "MM",
        "Asia/Bangkok": "TH",
        "Asia/Jakarta": "ID",
        "Asia/Singapore": "SG",
        "Asia/Kolkata": "IN",
        "Asia/Dhaka": "BD",
        "Asia/Shanghai": "CN",
        "Asia/Tokyo": "JP",
        "Asia/Seoul": "KR",
        "Asia/Ho_Chi_Minh": "VN",
        "Australia/Sydney": "AU",
        "Europe/London": "GB",
        "Europe/Paris": "FR",
        "Europe/Berlin": "DE",
        "America/New_York": "US",
        "America/Los_Angeles": "US",
        "America/Chicago": "US",
        "America/Sao_Paulo": "BR"
    })

    readonly property string countryLine: {
        const n = root.country.trim()
        if (n.length && n.length > 2)
            return n.toUpperCase()
        return root.iso2.length ? root.iso2 : "—"
    }

    readonly property string coordLine: {
        if (!root.hasCoords)
            return "—"
        const ns = root.lat >= 0 ? "N" : "S"
        const ew = root.lon >= 0 ? "E" : "W"
        return Math.abs(root.lat).toFixed(2) + "°" + ns + "  " + Math.abs(root.lon).toFixed(2) + "°" + ew
    }

    readonly property string publicLine: root.online && root.ip.length ? root.ip : "unknown IP"
    readonly property string localLine: root.localIp.length ? root.localIp : "unknown IP"

    function dropWan(): void {
        root.ip = ""
        if (!root.online)
            root.status = "OFFLINE"
    }

    function parseLink(raw: string): void {
        const lines = (raw || "").split("\n")
        let net = ""
        let lan = ""
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.indexOf("NET ") === 0)
                net = line.slice(4).trim().toLowerCase()
            else if (line.indexOf("LAN ") === 0)
                lan = line.slice(4).trim()
        }

        const up = net === "full" || net === "limited" || net === "portal"
            || net === "connected" || net.indexOf("full") !== -1
            || net === "up" || net.indexOf("connected") !== -1
        const wasUp = root.online
        root.localIp = lan
        root.online = up

        if (!up) {
            root.dropWan()
            root.localIp = ""
            geoRetry.stop()
            return
        }

        root.status = root.ip.length ? "FIX" : "PROBE"
        if (!wasUp || !root.ip.length)
            root.pullGeo()
    }

    function pullGeo(): void {
        if (!root.online)
            return
        if (geo.running)
            geo.running = false
        geo.running = true
    }

    function ingest(raw: string): void {
        if (!root.online) {
            root.dropWan()
            return
        }

        const t = (raw || "").trim()
        if (!t.length || t.charAt(0) !== "{") {
            root.dropWan()
            geoRetry.interval = 8000
            geoRetry.restart()
            return
        }
        let j
        try {
            j = JSON.parse(t)
        } catch (e) {
            root.dropWan()
            geoRetry.interval = 8000
            geoRetry.restart()
            return
        }
        if (j.success === false) {
            root.dropWan()
            geoRetry.interval = 8000
            geoRetry.restart()
            return
        }

        root.ip = j.ip || j.query || ""
        root.city = j.city || ""
        root.region = j.region || j.regionName || ""
        const cc = (j.country_code || j.countryCode || "").toString().toUpperCase()
        const countryVal = (j.country || j.country_name || "").toString()
        if (cc.length === 2)
            root.iso2 = cc
        else if (countryVal.length === 2)
            root.iso2 = countryVal.toUpperCase()
        if (countryVal.length > 2)
            root.country = countryVal
        else if (j.country_name)
            root.country = String(j.country_name)

        const conn = j.connection && typeof j.connection === "object" ? j.connection : null
        root.isp = (conn && (conn.isp || conn.org)) || j.isp || j.org || ""
        root.kind = (j.type || "").toString().toUpperCase()
        if (!root.kind.length)
            root.kind = root.ip.indexOf(":") >= 0 ? "IPV6" : (root.ip.length ? "IPV4" : "")

        if (typeof j.latitude === "number" && typeof j.longitude === "number") {
            root.lat = j.latitude
            root.lon = j.longitude
            root.hasCoords = true
        } else if (typeof j.lat === "number" && typeof j.lon === "number") {
            root.lat = j.lat
            root.lon = j.lon
            root.hasCoords = true
        } else if (typeof j.loc === "string" && j.loc.indexOf(",") > 0) {
            const bits = j.loc.split(",")
            root.lat = Number(bits[0]) || 0
            root.lon = Number(bits[1]) || 0
            root.hasCoords = true
        }

        const tz = j.timezone
        if (typeof tz === "string" && tz.length)
            root.tzName = tz
        else if (tz && typeof tz === "object") {
            if (tz.id)
                root.tzName = String(tz.id)
            if (tz.utc)
                root.tzOff = String(tz.utc)
            else if (tz.utc_offset)
                root.tzOff = String(tz.utc_offset)
        }

        if (!root.iso2.length && root.tzName.length)
            root.iso2 = root.tzMap[root.tzName] || ""

        root.hasFix = root.hasCoords || root.iso2.length > 0
        root.status = root.ip.length ? "FIX" : "PROBE"
        geoRetry.interval = root.ip.length ? 300000 : 8000
        geoRetry.restart()
    }

    Process {
        command: ["timedatectl", "show", "--property=Timezone", "--value"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const tz = text.trim()
                if (!tz.length)
                    return
                if (!root.tzName.length)
                    root.tzName = tz
                if (!root.iso2.length)
                    root.iso2 = root.tzMap[tz] || ""
                if (root.iso2.length)
                    root.hasFix = true
            }
        }
    }

    Process {
        id: link
        command: [
            "sh", "-c",
            "st=$(nmcli -t -f CONNECTIVITY general 2>/dev/null || true); "
            + "[ -z \"$st\" ] && st=$(nmcli -t -f STATE general 2>/dev/null | head -1 || true); "
            + "echo \"NET $st\"; "
            + "lan=$(ip -4 -o route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\"){print $(i+1); exit}}'); "
            + "if [ -z \"$lan\" ]; then "
            + "dev=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}'); "
            + "[ -n \"$dev\" ] && lan=$(ip -4 -o addr show dev \"$dev\" scope global 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1); "
            + "fi; "
            + "echo \"LAN $lan\""
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseLink(text)
        }
        onExited: {
            if (!linkPoll.running)
                linkPoll.restart()
        }
    }

    Process {
        id: watch
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if ((line || "").trim().length)
                    linkKick.restart()
            }
        }
        onExited: watchKick.restart()
    }

    Process {
        id: geo
        command: [
            "sh", "-c",
            "curl -fsS --max-time 4 https://ipwho.is/ || curl -fsS --max-time 4 https://ipinfo.io/json"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
        stderr: StdioCollector {}
        onExited: {
            if (exitCode !== 0 && root.online && !root.ip.length) {
                root.dropWan()
                geoRetry.interval = 8000
                geoRetry.restart()
            }
        }
    }

    Timer {
        id: linkKick
        interval: 200
        onTriggered: {
            if (link.running)
                link.running = false
            link.running = true
        }
    }

    Timer {
        id: linkPoll
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!link.running)
                link.running = true
        }
    }

    Timer {
        id: watchKick
        interval: 1000
        onTriggered: watch.running = true
    }

    Timer {
        id: geoRetry
        interval: 300000
        onTriggered: {
            if (root.online)
                root.pullGeo()
        }
    }
}
