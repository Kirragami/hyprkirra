pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool powered: {
        const a = root.adapter
        if (!a)
            return false
        if (a.enabled)
            return true
        const s = a.state
        return s === BluetoothAdapterState.Enabled || s === BluetoothAdapterState.Enabling
    }
    readonly property bool scanning: root.adapter ? root.adapter.discovering : false
    readonly property var devices: root.adapter ? root.adapter.devices : Bluetooth.devices

    readonly property bool linked: {
        if (!root.powered)
            return false
        const vals = root.deviceList()
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].connected)
                return true
        }
        return false
    }

    readonly property bool busy: {
        const vals = root.deviceList()
        for (let i = 0; i < vals.length; i++) {
            if (root.deviceBusy(vals[i]))
                return true
        }
        return false
    }

    readonly property string statusLine: {
        if (!root.available)
            return "NO RADIO"
        if (!root.powered)
            return "RADIO OFF"
        if (root.busy)
            return "LINKING"
        const vals = root.deviceList()
        const names = []
        for (let i = 0; i < vals.length; i++) {
            if (!vals[i].connected)
                continue
            const n = (vals[i].name || vals[i].deviceName || "").trim()
            if (n.length)
                names.push(n)
        }
        if (names.length)
            return names.join(" + ")
        return "NO LINK"
    }

    function deviceList(): var {
        const list = root.devices
        return list && list.values ? list.values : []
    }

    function deviceBusy(d: var): bool {
        if (!d)
            return false
        if (d.pairing)
            return true
        const s = d.state
        return s === BluetoothDeviceState.Connecting || s === BluetoothDeviceState.Disconnecting
    }

    function deviceLabel(d: var): string {
        if (!d)
            return "UNKNOWN"
        const n = (d.name || d.deviceName || "").trim()
        return n.length ? n : (d.address || "UNKNOWN")
    }

    function deviceHint(d: var): string {
        if (!d)
            return ""
        if (root.deviceBusy(d))
            return "WAIT"
        if (d.connected) {
            if (d.batteryAvailable)
                return Math.round(d.battery * 100) + "%"
            return "LIVE"
        }
        if (d.paired || d.bonded)
            return "HOLD"
        return "PAIR"
    }

    function togglePower(): void {
        if (!root.adapter)
            return
        root.adapter.enabled = !root.powered
    }

    function scan(on: bool): void {
        if (!root.adapter || !root.powered)
            return
        root.adapter.discovering = on
    }

    function toggleScan(): void {
        root.scan(!root.scanning)
    }

    function activate(d: var): void {
        if (!d || !root.powered)
            return
        if (d.pairing) {
            d.cancelPair()
            return
        }
        if (d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
            return
        if (d.connected) {
            d.disconnect()
            return
        }
        d.trusted = true
        if (d.paired || d.bonded)
            d.connect()
        else
            d.pair()
    }
}
