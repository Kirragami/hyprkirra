import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    PanelWindow {
        id: pane

        property bool isOpen: false
        readonly property int paneW: {
            const s = pane.screen
            const h = s && s.height > 1 ? s.height : 1080
            const w = s && s.width > 1 ? s.width : 1920
            const hubR = h * 0.4
            const need = Math.ceil(hubR * 1.42 + 214 + 38 + 34 + 80)
            const cap = Math.floor(w * 0.52)
            return Math.min(cap, Math.max(560, need))
        }

        implicitWidth: pane.paneW
        color: "transparent"
        visible: pane.isOpen || rail.mapped
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "kirrautil"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors.right: true
        anchors.top: true
        anchors.bottom: true

        margins.top: 0
        margins.bottom: 0
        margins.right: 0

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

        function toggle(): void {
            if (!pane.isOpen)
                pane.screen = pane.pickScreen()
            pane.isOpen = !pane.isOpen
        }

        property bool grabArmed: false

        onIsOpenChanged: {
            if (pane.isOpen)
                armGrab.restart()
            else
                pane.grabArmed = false
        }

        Timer {
            id: armGrab
            interval: 50
            onTriggered: pane.grabArmed = true
        }

        Component.onCompleted: pane.screen = pane.pickScreen()

        HyprlandFocusGrab {
            windows: [pane]
            active: pane.isOpen && pane.grabArmed
            onCleared: {
                if (pane.grabArmed && pane.isOpen)
                    pane.isOpen = false
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (pane.isOpen)
                    pane.isOpen = false
            }
        }

        IpcHandler {
            target: "kirrautil"
            function toggle(): void { pane.toggle() }
            function open(): void {
                pane.screen = pane.pickScreen()
                pane.isOpen = true
            }
            function close(): void { pane.isOpen = false }
            function isOpen(): bool { return pane.isOpen }
        }

        UtilRail {
            id: rail
            open: pane.isOpen
            anchors.fill: parent
            onDismiss: pane.isOpen = false
        }
    }
}
