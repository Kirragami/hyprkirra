import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: session
            required property var modelData

            CoverWatch {
                id: cover
                screen: session.modelData
            }

            PanelWindow {
                id: pane
                screen: session.modelData
                visible: true
                color: "transparent"
                anchors.left: true
                anchors.right: true
                anchors.top: true
                anchors.bottom: true
                exclusiveZone: -1
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}

                WlrLayershell.namespace: "kirracore"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                UsageBay {
                    id: core
                    paused: cover.paused
                }

                UsagePlate {
                    id: load
                    live: core.compact
                    visible: core.compact && !cover.paused
                    x: core.x + core.width * core.scale + 16
                    y: core.y + (core.height * core.scale - load.height) * 0.5
                }

                HudFrame {
                    visible: core.compact && !cover.paused
                    opacity: visible ? 1 : 0
                    pad: 0
                    arm: 14
                    thick: 1.15
                    inset: 3.5
                    x: core.x - 10
                    y: Math.min(core.y, load.y) - 10
                    width: load.x + load.width - core.x + 20
                    height: Math.max(core.height * core.scale, load.height) + 20

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
