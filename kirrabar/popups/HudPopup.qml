import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../fui"

PopupWindow {
    id: root

    property bool open: false
    property Item anchorItem: null
    property int paneWidth: 320
    property int paneHeight: 280
    property bool live: false
    property string plate: "blade"
    property bool scan: false
    property bool wipe: false

    default property alias content: inner.data

    property bool mapped: false
    property bool armed: false
    property real line: 0
    property real grow: 0
    property real pixels: 0
    property int hang: 2
    property int shiftX: 0
    property bool dropLine: false
    property bool ownGrab: true

    readonly property int stemMax: root.dropLine ? 1 : 0
    readonly property alias join: joinMark

    signal dismissed()

    grabFocus: false
    visible: mapped
    color: "transparent"
    implicitWidth: paneWidth
    implicitHeight: stemMax + paneHeight

    Item {
        id: joinMark
        width: 1
        height: 1
        x: Math.round((root.implicitWidth - 1) / 2)
        y: root.stemMax
    }

    anchor.item: root.anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: root.hang
    anchor.rect.x: {
        if (!root.anchorItem)
            return 0
        return Math.round((root.anchorItem.width - paneWidth) / 2) + root.shiftX
    }

    function dismiss(): void {
        if (root.open)
            root.dismissed()
    }

    onOpenChanged: {
        if (root.open) {
            outro.stop()
            root.mapped = true
            root.armed = false
            root.live = false
            intro.restart()
        } else {
            intro.stop()
            armGrab.stop()
            root.armed = false
            root.live = false
            if (root.mapped)
                outro.restart()
        }
    }

    onVisibleChanged: {
        if (!visible && root.open)
            root.dismissed()
    }

    SequentialAnimation {
        id: intro

        PropertyAction { target: root; property: "line"; value: 0 }
        PropertyAction { target: root; property: "grow"; value: 0 }
        PropertyAction { target: root; property: "pixels"; value: root.wipe ? 0 : 1 }

        PauseAnimation {
            duration: root.dropLine ? 0 : Theme.menuWaitMs
        }

        NumberAnimation {
            target: root
            property: "line"
            to: 1
            duration: root.dropLine ? 140 : 0
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "grow"
                to: 1
                duration: Theme.menuGrowMs
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "pixels"
                to: 1
                duration: root.wipe ? Math.min(140, Theme.menuGrowMs) : 0
                easing.type: Easing.Linear
            }
        }

        ScriptAction {
            script: {
                root.live = true
                armGrab.restart()
            }
        }
    }

    function kick(): void {
        if (!root.open || root.grow < 0.85)
            return
        root.pixels = 0.55
        kickAnim.restart()
    }

    NumberAnimation {
        id: kickAnim
        target: root
        property: "pixels"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: outro

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "pixels"
                to: 0
                duration: 60
            }
            NumberAnimation {
                target: root
                property: "grow"
                to: 0
                duration: 140
                easing.type: Easing.InCubic
            }
        }

        NumberAnimation {
            target: root
            property: "line"
            to: 0
            duration: 90
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                root.mapped = false
                root.armed = false
            }
        }
    }

    Timer {
        id: armGrab
        interval: 40
        onTriggered: root.armed = true
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.ownGrab && root.open && root.mapped && root.armed
        onCleared: {
            if (root.armed && root.open)
                root.dismiss()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.dismiss()
    }

    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: stemBox
            width: parent.width
            height: root.stemMax
            z: 2

            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                width: root.dropLine ? Math.max(0, parent.width * root.line) : 0
                color: Theme.line
            }
        }

        Item {
            id: paneClip
            width: parent.width
            height: root.paneHeight * root.grow
            y: stemBox.height
            clip: true

            Item {
                width: paneClip.width
                height: root.paneHeight

                HudChassis {
                    anchors.fill: parent
                    boot: 1
                    visible: root.plate === "hex"
                }

                HudBlade {
                    anchors.fill: parent
                    visible: root.plate === "blade"
                }

                ScanOverlay {
                    anchors.fill: parent
                    active: root.scan && root.grow > 0.2
                    enabled: false
                    opacity: 0.7
                    visible: root.scan
                }

                Item {
                    id: inner
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.topMargin: 16
                    anchors.rightMargin: root.plate === "blade" ? 28 : 16
                    anchors.bottomMargin: root.plate === "blade" ? 26 : 16
                    clip: true
                }

                Loader {
                    anchors.fill: parent
                    active: root.wipe
                    sourceComponent: Component {
                        PixelReveal {
                            progress: root.pixels
                        }
                    }
                }
            }
        }
    }
}
