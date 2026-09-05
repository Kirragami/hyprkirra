import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: session
            required property var modelData

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

                WlrLayershell.namespace: "kirraglobe"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Globe {
                    id: orb
                    screen: session.modelData
                }

                GeoPlate {
                    id: card
                    live: orb.compact
                    visible: orb.compact && !orb.paused
                    x: orb.x + orb.width * orb.scale + 16
                    y: orb.y + (orb.height * orb.scale - card.height) * 0.5
                }

                HudFrame {
                    id: bay
                    visible: orb.compact && !orb.paused
                    opacity: visible ? 1 : 0
                    pad: 0
                    arm: 14
                    thick: 1.15
                    inset: 3.5
                    x: orb.x - 10
                    y: Math.min(orb.y, card.y) - 10
                    width: card.x + card.width - orb.x + 20
                    height: Math.max(orb.height * orb.scale, card.height) + 20

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
