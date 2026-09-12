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

                WlrLayershell.namespace: "kirractrl"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                CtrlBay {
                    id: bay
                    paused: cover.paused
                }
            }
        }
    }
}
