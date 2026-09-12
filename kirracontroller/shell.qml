import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "svc"

ShellRoot {
    IpcHandler {
        target: "kirracontroller"
        function power(): void {
            Command.callPower()
        }
        function close(): void {
            Command.dismiss()
        }
        function isOpen(): bool {
            return Command.armed
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: session
            required property var modelData

            readonly property bool onFocusedMonitor: {
                const mon = Hyprland.focusedMonitor
                if (!mon)
                    return true
                const hit = Hyprland.monitorFor(session.modelData)
                return !!(hit && hit.id === mon.id)
            }

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
                WlrLayershell.namespace: "kirractrl"
                WlrLayershell.layer: bay.lifted ? WlrLayer.Overlay : WlrLayer.Bottom
                WlrLayershell.keyboardFocus: bay.lifted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                mask: bay.lifted ? hitMask : passMask

                Region {
                    id: passMask
                }

                Region {
                    id: hitMask
                    item: pane.contentItem
                }

                Shortcut {
                    sequence: "Escape"
                    enabled: bay.lifted
                    onActivated: Command.dismiss()
                }

                Shortcut {
                    sequence: "Up"
                    enabled: bay.lifted
                    onActivated: bay.pick(1)
                }

                Shortcut {
                    sequence: "Down"
                    enabled: bay.lifted
                    onActivated: bay.pick(-1)
                }

                Shortcut {
                    sequence: "Return"
                    enabled: bay.lifted
                    onActivated: bay.confirm()
                }

                Shortcut {
                    sequence: "Enter"
                    enabled: bay.lifted
                    onActivated: bay.confirm()
                }

                Shortcut {
                    sequence: "Space"
                    enabled: bay.lifted
                    onActivated: bay.confirm()
                }

                Connections {
                    target: Command
                    function onPower() {
                        if (session.onFocusedMonitor)
                            bay.wakePower()
                    }
                    function onClose() {
                        bay.sleep()
                    }
                }

                CtrlBay {
                    id: bay
                    paused: cover.paused
                }
            }
        }
    }
}
