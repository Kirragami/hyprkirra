import Quickshell
import Quickshell.Io
import QtQuick
import "fui"
import "modules"

ShellRoot {
    IpcHandler {
        target: "kirrabar"
        function toggleNotifs(): void {
            BarGate.toggle("mail")
        }
        function toggleCal(): void {
            BarGate.toggle("cal")
        }
        function close(): void {
            BarGate.close()
        }
        function isOpen(): bool {
            return BarGate.openCount > 0
        }
    }

    KirraBar {}
}
