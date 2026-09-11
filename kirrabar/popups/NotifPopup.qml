import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../fui"

PanelWindow {
    id: pop

    property bool open: false
    property bool attached: true
    property Item anchorItem: null
    property int hang: 2
    property int shiftX: 0
    property bool purging: false
    property bool mapped: false
    property bool armed: false
    property bool live: false
    property real grow: 0
    property int placeX: 8
    property int placeY: 8

    readonly property alias join: joinMark
    readonly property int useHang: pop.attached ? pop.hang : 12

    signal dismissed()

    visible: mapped
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 480
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    WlrLayershell.namespace: "kirrabar-alerts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    margins.left: pop.placeX
    margins.top: pop.placeY

    Item {
        id: joinMark
        width: 1
        height: 1
        x: 200
        y: 0
    }

    function syncPlace(): void {
        const scr = pop.screen
        const paneW = 400
        if (!scr) {
            pop.placeX = 8
            pop.placeY = pop.useHang
            return
        }
        if (!pop.attached || !pop.anchorItem) {
            pop.placeX = Math.max(8, scr.width - paneW - 16)
            pop.placeY = 16
            return
        }
        const item = pop.anchorItem
        const mid = item.mapToGlobal(item.width / 2, item.height)
        if (!isFinite(mid.x) || !isFinite(mid.y))
            return
        const maxX = Math.max(8, scr.width - paneW - 8)
        const x = Math.round(mid.x - paneW / 2 + pop.shiftX - scr.x)
        const y = Math.round(mid.y + pop.useHang - scr.y)
        pop.placeX = Math.max(8, Math.min(x, maxX))
        pop.placeY = Math.max(8, y)
    }

    function dismiss(): void {
        if (pop.open)
            pop.dismissed()
    }

    function purgeAll(): void {
        if (pop.purging || !Notifs.pending)
            return
        if (Notifs.items.length === 0) {
            Notifs.clearAll()
            return
        }
        pop.purging = true
        purgeHold.restart()
    }

    onOpenChanged: {
        if (pop.open) {
            outro.stop()
            pop.syncPlace()
            pop.mapped = true
            pop.armed = false
            pop.live = false
            intro.restart()
        } else {
            intro.stop()
            armGrab.stop()
            pop.armed = false
            pop.live = false
            if (pop.mapped)
                outro.restart()
        }
    }

    onAttachedChanged: {
        if (pop.open || pop.mapped)
            pop.syncPlace()
    }

    Timer {
        interval: 16
        running: pop.mapped
        repeat: true
        onTriggered: pop.syncPlace()
    }

    SequentialAnimation {
        id: intro

        PropertyAction { target: pop; property: "grow"; value: 0 }

        PauseAnimation {
            duration: pop.attached ? Theme.menuWaitMs : 0
        }

        NumberAnimation {
            target: pop
            property: "grow"
            to: 1
            duration: Theme.menuGrowMs
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: {
                if (pop.open) {
                    pop.live = true
                    armGrab.restart()
                }
            }
        }
    }

    NumberAnimation {
        id: outro
        target: pop
        property: "grow"
        to: 0
        duration: 140
        easing.type: Easing.InCubic
        onStopped: {
            pop.mapped = false
            pop.armed = false
        }
    }

    Timer {
        id: armGrab
        interval: 40
        onTriggered: pop.armed = true
    }

    Timer {
        id: purgeHold
        interval: 180
        onTriggered: {
            Notifs.clearAll()
            pop.purging = false
        }
    }

    HyprlandFocusGrab {
        windows: [pop]
        active: pop.open && pop.mapped && pop.armed
        onCleared: {
            if (pop.armed && pop.open)
                pop.dismiss()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: pop.open
        onActivated: pop.dismiss()
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        width: 400
        height: 480 * pop.grow
        clip: true

        Item {
            width: 400
            height: 480

            HudBlade {
                anchors.fill: parent
            }

            Column {
                id: col
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.topMargin: 16
                anchors.rightMargin: 28
                anchors.bottomMargin: 26
                spacing: 8

                GlitchText {
                    value: "SYS // ALERTS"
                    settled: true
                    color: Theme.textMute
                    font.family: Theme.fontHud
                    font.pixelSize: 12
                    font.letterSpacing: 1.8
                    font.bold: true
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.lineFaint
                }

                HudRow {
                    width: parent.width
                    label: "CLEAR ALL"
                    hint: Notifs.pending ? String(Notifs.count) : "—"
                    enabled: Notifs.pending && !pop.purging
                    onClicked: pop.purgeAll()
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.lineFaint
                }

                Flickable {
                    width: parent.width
                    height: Math.max(120, col.height - y)
                    clip: true
                    contentHeight: listCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: listCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: Notifs.items

                            Item {
                                id: card
                                required property var modelData
                                width: listCol.width
                                height: bodyLine.visible ? 80 : 50
                                clip: true

                                property bool bye: false
                                readonly property bool leaving: card.bye || pop.purging
                                readonly property string iconSrc: Notifs.icon(modelData)
                                readonly property string bodyText: Notifs.body(modelData)

                                onLeavingChanged: {
                                    if (card.leaving)
                                        fx.play(160)
                                }

                                GlitchReveal {
                                    id: fx
                                    anchors.fill: parent
                                    duration: 160
                                    intensity: 0.8
                                    slices: 4
                                    opacity: card.leaving ? 0 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.InCubic
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: hit.containsMouse && !card.leaving ? Theme.bgRaised : "transparent"
                                        border.color: hit.containsMouse && !card.leaving ? Theme.lineDim : "transparent"
                                        border.width: 1
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8

                                        Rectangle {
                                            id: pip
                                            width: 6
                                            height: 6
                                            rotation: 45
                                            color: "transparent"
                                            border.color: Theme.lineDim
                                            border.width: 1
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.topMargin: 12
                                        }

                                        Image {
                                            id: glyph
                                            visible: card.iconSrc.length > 0
                                            source: card.iconSrc
                                            width: 20
                                            height: 20
                                            sourceSize.width: 20
                                            sourceSize.height: 20
                                            fillMode: Image.PreserveAspectFit
                                            anchors.left: pip.right
                                            anchors.leftMargin: 8
                                            anchors.top: parent.top
                                            anchors.topMargin: 8
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.topMargin: 8
                                            text: Notifs.hint(card.modelData)
                                            color: Theme.textDim
                                            font.family: Theme.fontMono
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            id: sumLine
                                            width: parent.width - (glyph.visible ? 52 : 22)
                                            text: Notifs.summary(card.modelData)
                                            color: Theme.text
                                            font.family: Theme.fontMono
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            anchors.left: glyph.visible ? glyph.right : pip.right
                                            anchors.leftMargin: 8
                                            anchors.right: parent.right
                                            anchors.rightMargin: 44
                                            anchors.top: parent.top
                                            anchors.topMargin: 10
                                        }

                                        Text {
                                            id: bodyLine
                                            visible: card.bodyText.length > 0
                                            width: parent.width - (glyph.visible ? 52 : 22)
                                            height: 28
                                            text: card.bodyText
                                            color: Theme.textDim
                                            font.family: Theme.fontMono
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            clip: true
                                            anchors.left: glyph.visible ? glyph.right : pip.right
                                            anchors.leftMargin: 8
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 8
                                        }
                                    }
                                }

                                MouseArea {
                                    id: hit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !card.leaving
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.bye = true
                                }

                                Timer {
                                    interval: 170
                                    running: card.bye && !pop.purging
                                    onTriggered: Notifs.dismiss(card.modelData)
                                }
                            }
                        }

                        Text {
                            visible: !Notifs.pending
                            text: "NO ALERTS"
                            color: Theme.textMute
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
