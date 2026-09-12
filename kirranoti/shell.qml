import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    PanelWindow {
        id: pane

        readonly property bool showing: bay.count > 0

        implicitWidth: bay.implicitWidth
        implicitHeight: bay.bayH
        color: "transparent"
        visible: pane.showing
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        WlrLayershell.namespace: "kirranoti"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.right: true
        anchors.top: true
        margins.top: 108
        margins.right: 18

        mask: Region {
            item: stackHit
        }

        function pickScreen(): var {
            const list = Quickshell.screens
            if (!list.length)
                return null
            const mon = Hyprland.focusedMonitor
            if (!mon)
                return list[0]
            for (let i = 0; i < list.length; i++) {
                const hit = Hyprland.monitorFor(list[i])
                if (hit && hit.id === mon.id)
                    return list[i]
            }
            return list[0]
        }

        Component.onCompleted: pane.screen = pane.pickScreen()

        ToastBay {
            id: bay
            anchors.fill: parent
            onCountChanged: {
                if (bay.count > 0)
                    pane.screen = pane.pickScreen()
            }
        }

        Item {
            id: stackHit
            x: 0
            y: 0
            width: bay.cardW
            height: bay.packH
        }
    }
}
