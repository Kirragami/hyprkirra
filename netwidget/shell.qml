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

                WlrLayershell.namespace: "kirranet"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                NetBay {
                    id: bay
                    paused: cover.paused
                }

                NetPlate {
                    id: link
                    live: bay.compact
                    visible: bay.compact && !cover.paused
                    span: bay.plateW
                    x: bay.x + bay.width * bay.scale + bay.textGap
                    y: bay.y + (bay.height * bay.scale - link.height) * 0.5
                }

                HudFrame {
                    visible: bay.compact && !cover.paused
                    opacity: visible ? 1 : 0
                    pad: 0
                    arm: 14
                    thick: 1.15
                    inset: 3.5
                    x: bay.x - bay.framePad
                    y: bay.y - bay.framePad
                    width: link.x + link.width - bay.x + bay.framePad * 2
                    height: bay.dock + bay.framePad * 2

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
