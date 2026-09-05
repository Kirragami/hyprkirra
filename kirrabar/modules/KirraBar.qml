pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import "../fui"
import "../popups"

Variants {
    model: Quickshell.screens

    Scope {
        id: session
        required property var modelData

        PanelWindow {
            id: panel
            screen: session.modelData

        color: "transparent"
        implicitHeight: Theme.barHeight
        anchors.top: true
        anchors.left: true
        anchors.right: true
        margins.top: 8
        margins.left: 12
        margins.right: 12
        exclusiveZone: Theme.barHeight + 8
        exclusionMode: ExclusionMode.Normal

        WlrLayershell.namespace: "kirrabar"
        WlrLayershell.layer: WlrLayer.Top

        property real boot: 0
        property bool identLive: false
        property bool sectorLive: false
        property bool clockLive: false
        property bool telLive: false
        property string hexBeat: "A7F0C21D"
        property string menu: ""
        property var trayHandle: null
        property Item trayAnchor: null

        readonly property var bat: UPower.displayDevice
        readonly property bool hasBattery: bat && bat.isLaptopBattery && bat.isPresent
        readonly property int batPct: bat ? Math.round(bat.percentage * 100) : 0

        readonly property PwNode sink: Pipewire.defaultAudioSink
        readonly property bool volReady: sink !== null && sink.ready && sink.audio !== null
        readonly property bool volMuted: volReady ? sink.audio.muted : false
        readonly property int volPct: volReady && !volMuted ? Math.round(Math.min(1, sink.audio.volume) * 100) : 0

        readonly property Item lockFace: {
            const m = panel.menu
            if (m === "cal")
                return clock
            if (m === "vol")
                return volMeter
            if (m === "bat")
                return batMeter
            if (m === "wifi")
                return netPip
            if (m === "bt")
                return btPip
            if (m === "mail")
                return mailPip
            if (m === "tray")
                return panel.trayAnchor
            if (m === "aud")
                return nowPlaying.artFace
            return null
        }
        readonly property Item lockJoin: {
            const m = panel.menu
            if (m === "cal")
                return calPop.join
            if (m === "vol")
                return volPop.join
            if (m === "bat")
                return batPop.join
            if (m === "wifi")
                return wifiPop.join
            if (m === "bt")
                return btPop.join
            if (m === "mail")
                return mailPop.join
            if (m === "tray")
                return trayPop.join
            if (m === "aud")
                return audPop.join
            return null
        }

        function lockHang(item: Item): int {
            if (!item)
                return 120
            return Math.round(item.lockR - item.height * 0.5 + 120)
        }

        function toggleMenu(name: string): void {
            panel.menu = panel.menu === name ? "" : name
        }

        function isWifiTray(item: var): bool {
            if (!item)
                return false
            const blob = [item.id, item.title, item.tooltipTitle, item.icon]
                .map(v => (v || "").toString().toLowerCase())
                .join(" ")
            return blob.includes("nm-applet")
                || blob.includes("nm-connection")
                || blob.includes("network-manager")
                || blob.includes("networkmanager")
                || blob.includes("wifi")
                || blob.includes("wireless")
                || /\bnetwork\b/.test(blob)
        }

        function isBtTray(item: var): bool {
            if (!item)
                return false
            const blob = [item.id, item.title, item.tooltipTitle, item.icon]
                .map(v => (v || "").toString().toLowerCase())
                .join(" ")
            return blob.includes("blueman")
                || blob.includes("blueberry")
                || blob.includes("blueman-applet")
                || blob.includes("blueman-tray")
                || blob.includes("bluetooth")
        }

        function openTray(handle: var, item: Item): void {
            if (panel.menu === "tray" && panel.trayAnchor === item) {
                panel.menu = ""
                return
            }
            panel.trayHandle = handle
            panel.trayAnchor = item
            panel.menu = "tray"
        }

        function fmtSecs(secs: real): string {
            if (!secs || secs <= 0)
                return "—"
            const h = Math.floor(secs / 3600)
            const m = Math.floor((secs % 3600) / 60)
            return (h > 0 ? h + "H " : "") + m + "M"
        }

        PwObjectTracker {
            objects: panel.sink !== null ? [panel.sink] : []
        }

        SequentialAnimation on boot {
            running: true
            PauseAnimation { duration: 30 }
            PropertyAction { value: 0.2 }
            PauseAnimation { duration: 40 }
            PropertyAction { value: 0.55 }
            PauseAnimation { duration: 30 }
            NumberAnimation {
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Timer { interval: 70; running: true; onTriggered: panel.identLive = true }
        Timer { interval: 120; running: true; onTriggered: panel.sectorLive = true }
        Timer { interval: 160; running: true; onTriggered: panel.clockLive = true }
        Timer { interval: 200; running: true; onTriggered: panel.telLive = true }

        Timer {
            interval: 220
            running: true
            repeat: true
            onTriggered: {
                const n = Date.now()
                panel.hexBeat = ((n * 2654435761) >>> 0).toString(16).toUpperCase().padStart(8, "0")
            }
        }

        GlitchReveal {
            id: fx
            anchors.fill: parent
            clip: false
            autoPlay: true
            duration: 320
            intensity: 0.5
            slices: 5

            HudChassis {
                anchors.fill: parent
                boot: panel.boot
            }

            TickRail {
                anchors.fill: parent
                opacity: panel.boot
            }

            ScanOverlay {
                anchors.fill: parent
                active: panel.boot > 0.85
                opacity: Math.max(0, panel.boot - 0.35)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                width: parent.width * Math.min(1, panel.boot * 1.8)
                color: Theme.line
                opacity: panel.boot < 0.9 ? (1 - panel.boot * 0.85) : 0
            }

            Item {
                id: hud
                anchors.fill: parent
                anchors.leftMargin: Theme.contentPad
                anchors.rightMargin: Theme.contentPad
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                opacity: panel.boot < 0.18 ? 0 : Math.min(1, (panel.boot - 0.18) / 0.3)

                Row {
                    id: leftHud
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Reticle {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter

                            GlitchText {
                                value: "KIRRA"
                                settled: panel.identLive
                                color: Theme.text
                                font.family: Theme.fontHud
                                font.pixelSize: 15
                                font.bold: true
                                font.letterSpacing: 3.2
                            }

                            GlitchText {
                                value: panel.identLive ? panel.hexBeat : "BOOT"
                                settled: panel.identLive
                                glitchOnChange: false
                                color: Theme.textMute
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                font.letterSpacing: 1.1
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 22
                        color: Theme.lineFaint
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    WorkspaceStrip {
                        minWorkspaces: 5
                        opacity: panel.sectorLive ? 1 : 0.35
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MissionClock {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    x: (nowPlaying.live || nowPlaying.width > 8) ? leftHud.width + 16 : Math.round((hud.width - width) / 2)
                    settled: panel.clockLive
                    selected: panel.menu === "cal"
                    onClicked: panel.toggleMenu("cal")

                    Behavior on x {
                        NumberAnimation {
                            duration: 360
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                NowPlaying {
                    id: nowPlaying
                    anchors.verticalCenter: parent.verticalCenter
                    x: clock.x + clock.width
                    width: live ? Math.max(0, rightHud.x - x - 18) : 0
                    settled: panel.clockLive
                    selected: panel.menu === "aud"
                    onClicked: panel.toggleMenu("aud")
                    onLiveChanged: {
                        if (!live && panel.menu === "aud")
                            panel.menu = ""
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 360
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: rightHud
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 32

                    Row {
                        spacing: 28
                        anchors.verticalCenter: parent.verticalCenter

                    Meter {
                        id: volMeter
                        label: panel.volMuted ? "MUTE" : "VOL"
                        value: panel.volPct
                        settled: panel.telLive
                        interactive: true
                        selected: panel.menu === "vol"
                        onWheel: dir => {
                            if (!panel.volReady)
                                return
                            panel.sink.audio.muted = false
                            panel.sink.audio.volume = Math.max(0, Math.min(1, panel.sink.audio.volume + dir * 0.05))
                        }
                        onClicked: panel.toggleMenu("vol")
                        onRightClicked: {
                            if (panel.volReady)
                                panel.sink.audio.muted = !panel.sink.audio.muted
                        }
                    }

                    Meter {
                        id: batMeter
                        visible: panel.hasBattery
                        label: UPower.onBattery ? "BAT" : "AC"
                        value: panel.batPct
                        settled: panel.telLive
                        interactive: true
                        selected: panel.menu === "bat"
                        onClicked: panel.toggleMenu("bat")
                    }

                    PulsePip {
                        id: netPip
                        label: "NET"
                        live: Telemetry.netUp || Network.wired || Network.activeSsid.length > 0
                        settled: panel.telLive
                        selected: panel.menu === "wifi"
                        opacity: panel.telLive ? 1 : 0.25
                        onClicked: panel.toggleMenu("wifi")
                    }

                    PulsePip {
                        id: btPip
                        label: "BT"
                        live: Bt.linked
                        settled: panel.telLive
                        selected: panel.menu === "bt"
                        opacity: panel.telLive ? 1 : 0.25
                        onClicked: panel.toggleMenu("bt")
                    }

                    NotifPip {
                        id: mailPip
                        pending: Notifs.pending
                        settled: panel.telLive
                        selected: panel.menu === "mail"
                        opacity: panel.telLive ? 1 : 0.25
                        onClicked: panel.toggleMenu("mail")
                    }
                    }

                    Row {
                        spacing: 12
                        visible: SystemTray.items.values.length > 0
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: SystemTray.items

                            MouseArea {
                                id: trayItem
                                required property var modelData
                                visible: !panel.isWifiTray(modelData) && !panel.isBtTray(modelData)
                                implicitWidth: visible ? 26 : 0
                                implicitHeight: 26
                                clip: false
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                readonly property real lockInner: Theme.lockInner(width, height, 8)
                                readonly property real lockR: Theme.lockR(width, height, 8)

                                Image {
                                    anchors.centerIn: parent
                                    source: trayItem.modelData.icon
                                    width: 18
                                    height: 18
                                    sourceSize.width: 18
                                    sourceSize.height: 18
                                    fillMode: Image.PreserveAspectFit
                                    opacity: 0.85
                                    scale: panel.menu === "tray" && panel.trayAnchor === trayItem ? 1.22 : 1
                                    transformOrigin: Item.Center

                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.zoomMs; easing.type: Easing.OutCubic }
                                    }
                                }

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton && !modelData.onlyMenu)
                                        modelData.activate()
                                    else if (modelData.hasMenu)
                                        panel.openTray(modelData.menu, trayItem)
                                    else
                                        modelData.secondaryActivate()
                                }
                            }
                        }
                    }
                }
            }
        }

        CalendarPopup {
            id: calPop
            open: panel.menu === "cal"
            anchorItem: clock
            hang: panel.lockHang(clock)
            shiftX: -88
            onDismissed: if (panel.menu === "cal") panel.menu = ""
        }

        MusicPopup {
            id: audPop
            open: panel.menu === "aud"
            anchorItem: nowPlaying.artFace
            hang: panel.lockHang(nowPlaying.artFace)
            shiftX: -88
            player: nowPlaying.player
            playing: nowPlaying.playing
            title: nowPlaying.title
            artist: nowPlaying.artist
            onDismissed: if (panel.menu === "aud") panel.menu = ""
        }

        AudioPopup {
            id: volPop
            open: panel.menu === "vol"
            anchorItem: volMeter
            hang: panel.lockHang(volMeter)
            shiftX: -88
            sink: panel.sink
            ready: panel.volReady
            muted: panel.volMuted
            percent: panel.volPct
            onDismissed: if (panel.menu === "vol") panel.menu = ""
        }

        BatteryPopup {
            id: batPop
            open: panel.menu === "bat"
            anchorItem: batMeter
            hang: panel.lockHang(batMeter)
            shiftX: -88
            percent: panel.batPct
            discharging: UPower.onBattery
            eta: panel.fmtSecs(UPower.onBattery ? panel.bat.timeToEmpty : panel.bat.timeToFull)
            rate: panel.bat && panel.bat.changeRate ? (Math.abs(panel.bat.changeRate).toFixed(1) + " W") : "—"
            onDismissed: if (panel.menu === "bat") panel.menu = ""
        }

        WifiPopup {
            id: wifiPop
            open: panel.menu === "wifi"
            anchorItem: netPip
            hang: panel.lockHang(netPip)
            shiftX: -88
            onDismissed: if (panel.menu === "wifi") panel.menu = ""
        }

        BtPopup {
            id: btPop
            open: panel.menu === "bt"
            anchorItem: btPip
            hang: panel.lockHang(btPip)
            shiftX: -88
            onDismissed: if (panel.menu === "bt") panel.menu = ""
        }

        NotifPopup {
            id: mailPop
            open: panel.menu === "mail"
            anchorItem: mailPip
            hang: panel.lockHang(mailPip)
            shiftX: -88
            onDismissed: if (panel.menu === "mail") panel.menu = ""
        }

        TrayPopup {
            id: trayPop
            open: panel.menu === "tray"
            anchorItem: panel.trayAnchor
            hang: panel.lockHang(panel.trayAnchor)
            shiftX: -88
            menuHandle: panel.trayHandle
            onDismissed: if (panel.menu === "tray") panel.menu = ""
        }

        LockOverlay {
            screen: session.modelData
            originWindow: panel
            faceItem: panel.lockFace
            joinItem: panel.lockJoin
            locked: panel.menu === "cal" || panel.menu === "vol" || panel.menu === "bat" || panel.menu === "wifi" || panel.menu === "bt" || panel.menu === "mail" || panel.menu === "tray" || panel.menu === "aud"
            gap: 120
            offsetX: -88
        }
    }
}
}
