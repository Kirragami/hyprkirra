pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick

Item {
    id: strip
    property int minWorkspaces: 5
    property int shownId: 0
    property string openSpecial: ""

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property string focusedName: Hyprland.focusedWorkspace ? (Hyprland.focusedWorkspace.name || "") : ""

    function canonSpecial(name: string): string {
        const n = (name || "").trim()
        if (!n.length)
            return ""
        if (n === "special" || n.indexOf("special:") === 0)
            return n
        return "special:" + n
    }

    function specialsMatch(a: string, b: string): bool {
        const ca = strip.canonSpecial(a)
        const cb = strip.canonSpecial(b)
        return ca.length > 0 && ca === cb
    }

    function setOpenSpecial(raw: string): void {
        const name = strip.canonSpecial(raw)
        if (strip.openSpecial === name)
            return
        strip.openSpecial = name
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        Qt.callLater(strip.settleToFocus)
    }

    function settleToFocus(): void {
        if (strip.openSpecial.length) {
            const ws = strip.workspaceByName(strip.openSpecial)
            if (ws)
                strip.shownId = ws.id
            else if (Hyprland.focusedWorkspace)
                strip.shownId = Hyprland.focusedWorkspace.id
            return
        }
        const mon = Hyprland.focusedMonitor
        if (mon && mon.activeWorkspace && mon.activeWorkspace.id > 0) {
            strip.shownId = mon.activeWorkspace.id
            return
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
            strip.shownId = Hyprland.focusedWorkspace.id
    }

    onFocusedIdChanged: strip.settleToFocus()

    Component.onCompleted: strip.settleToFocus()

    implicitWidth: row.implicitWidth
    implicitHeight: 38

    readonly property var workspaceIds: {
        let maxId = Math.max(1, strip.minWorkspaces)
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].id > maxId)
                maxId = list[i].id
        }
        const ids = []
        for (let id = 1; id <= maxId; id++)
            ids.push(id)
        return ids
    }

    readonly property var specials: {
        const list = Hyprland.workspaces.values
        const out = []
        const seen = {}
        for (let i = 0; i < list.length; i++) {
            const n = list[i].name || ""
            if ((n === "special" || n.indexOf("special:") === 0) && !seen[n]) {
                seen[n] = true
                out.push({ id: list[i].id, name: n })
            }
        }
        if (out.length === 0)
            out.push({ id: 0, name: "special" })
        return out
    }

    function workspaceById(id: int): var {
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i]
        }
        return null
    }

    function workspaceByName(name: string): var {
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++) {
            if ((list[i].name || "") === name)
                return list[i]
        }
        return null
    }

    function specialTag(name: string): string {
        if (!name || name === "special")
            return "S"
        if (name.indexOf("special:") === 0) {
            const rest = name.slice(8)
            if (rest.length <= 2)
                return rest.toUpperCase()
            return rest.charAt(0).toUpperCase()
        }
        return "S"
    }

    function activate(id: int): void {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({workspace = '" + id + "'})")
        else
            Hyprland.dispatch("workspace " + id)
    }

    function toggleSpecial(name: string): void {
        const key = !name || name === "special" ? "" : name.replace(/^special:/, "")
        Hyprland.dispatch(key.length ? "togglespecialworkspace " + key : "togglespecialworkspace")
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            const n = event.name
            if (n === "activespecial") {
                const data = event.data || ""
                const comma = data.indexOf(",")
                strip.setOpenSpecial(comma >= 0 ? data.slice(0, comma) : data)
            } else if (n === "activespecialv2") {
                const parts = (event.data || "").split(",")
                strip.setOpenSpecial(parts.length > 1 ? parts[1] : "")
            } else if (n === "createworkspace" || n === "createworkspacev2"
                    || n === "destroyworkspace" || n === "destroyworkspacev2") {
                Hyprland.refreshWorkspaces()
            }
        }
    }

    component WsNode: Item {
        id: node
        property int wsId: 0
        property string wsName: ""
        property bool special: false

        readonly property var wsObj: node.special ? strip.workspaceByName(node.wsName) : strip.workspaceById(node.wsId)
        readonly property bool isActive: node.special
            ? strip.specialsMatch(strip.openSpecial, node.wsName)
            : (strip.shownId === node.wsId && strip.openSpecial.length === 0)
        readonly property bool occupied: {
            if (node.special) {
                const ws = node.wsObj
                if (!ws)
                    return false
                const tops = ws.toplevels
                return tops && tops.values && tops.values.length > 0
            }
            return node.wsObj !== null
        }
        readonly property bool urgent: node.wsObj ? node.wsObj.urgent : false
        readonly property string glyph: node.special
            ? strip.specialTag(node.wsName)
            : (node.wsId < 10 ? "0" + node.wsId : "" + node.wsId)

        implicitWidth: 38
        implicitHeight: 38
        clip: false
        scale: node.isActive ? Theme.pickZoom : 1
        transformOrigin: Item.Center
        property real ringForm: 0
        readonly property bool wantRings: node.isActive || hover.containsMouse

        Behavior on scale {
            NumberAnimation { duration: Theme.zoomMs; easing.type: Easing.OutCubic }
        }

        onWantRingsChanged: {
            if (node.wantRings) {
                formOut.stop()
                formIn.restart()
            } else {
                formIn.stop()
                formOut.restart()
            }
        }

        NumberAnimation {
            id: formIn
            target: node
            property: "ringForm"
            to: 1
            duration: 340
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: formOut
            target: node
            property: "ringForm"
            to: 0
            duration: 240
            easing.type: Easing.InCubic
        }

        Component.onCompleted: {
            if (node.wantRings)
                formIn.restart()
        }

        HudRing {
            anchors.fill: parent
            radius: 16.5
            gapDeg: 72
            startDeg: -50
            weight: 1.4
            stroke: Theme.line
            form: node.ringForm
            spinMs: Theme.ringSpinOutMs
            opacity: node.isActive ? 1 : 0.4
            visible: node.ringForm > 0.01
        }

        HudRing {
            anchors.fill: parent
            radius: 12
            gapDeg: 88
            startDeg: 110
            weight: 1.2
            stroke: Theme.line
            form: node.ringForm
            reverse: true
            spinClockwise: false
            spinMs: Theme.ringSpinInMs
            opacity: node.isActive ? 0.9 : 0.3
            visible: node.ringForm > 0.01
        }

        Text {
            anchors.centerIn: parent
            text: node.glyph
            color: node.isActive ? Theme.text : (node.occupied || hover.containsMouse ? Theme.text : Theme.textMute)
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.bold: true
            opacity: node.isActive || node.occupied || hover.containsMouse ? 1 : 0.45

            SequentialAnimation on opacity {
                running: node.urgent && !node.isActive
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 280 }
                NumberAnimation { to: 1.0; duration: 280 }
            }
        }

        Rectangle {
            visible: node.occupied && !node.isActive
            width: 3
            height: 3
            rotation: 45
            color: Theme.line
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (node.special)
                    strip.toggleSpecial(node.wsName)
                else
                    strip.activate(node.wsId)
            }
        }
    }

    Row {
        id: row
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: strip.workspaceIds
            WsNode {
                required property var modelData
                wsId: modelData
                wsName: "" + modelData
                special: false
            }
        }

        Rectangle {
            width: 1
            height: 16
            color: Theme.lineFaint
            anchors.verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: strip.specials
            WsNode {
                required property var modelData
                wsId: modelData.id
                wsName: modelData.name
                special: true
            }
        }
    }
}
