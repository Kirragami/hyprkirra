pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: gate

    property int openCount: 0

    signal requestToggle(string name)
    signal requestClose()

    function toggle(name: string): void {
        gate.requestToggle(name)
    }

    function close(): void {
        gate.requestClose()
    }

    function noteOpen(wasOpen: bool, nowOpen: bool): void {
        if (wasOpen === nowOpen)
            return
        if (nowOpen)
            gate.openCount += 1
        else
            gate.openCount = Math.max(0, gate.openCount - 1)
    }
}
