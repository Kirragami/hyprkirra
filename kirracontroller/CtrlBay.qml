pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "svc"

Item {
    id: bay

    property bool paused: false
    property real appear: 0
    property real boot: 0
    property real heat: 0
    property real fire: 0
    property real veil: 0
    property bool locked: false
    property bool armed: false
    property int selected: 0
    property string mode: ""
    property string query: ""
    property string selectedId: ""
    property string selectedName: ""
    property int seekLive: 0

    readonly property bool lifted: bay.armed || bay.heat > 0.01 || bay.fire > 0.01 || bay.veil > 0.01
    readonly property real pad: 10
    readonly property real padY: 34
    readonly property real dock: 312
    readonly property real framePad: 10
    readonly property real clusterGap: 20
    readonly property real slabGap: 8
    readonly property real seekLift: 50
    readonly property var powerActs: [
        {
            tag: "LOCK",
            arg: "lock",
            icon: "icons/lock.svg"
        },
        {
            tag: "SUSPEND",
            arg: "suspend",
            icon: "icons/suspend.svg"
        },
        {
            tag: "LOGOUT",
            arg: "exit",
            icon: "icons/logout.svg"
        },
        {
            tag: "REBOOT",
            arg: "reboot",
            icon: "icons/reboot.svg"
        },
        {
            tag: "SHUTDOWN",
            arg: "shutdown",
            icon: "icons/power.svg"
        }
    ]
    readonly property int slabCount: bay.powerActs.length
    readonly property string powerSh: `${Quickshell.env("HOME")}/.config/hypr/scripts/power.sh`
    readonly property real viewW: {
        const p = bay.parent
        return p && p.width > 1 ? p.width : 1920
    }
    readonly property real viewH: {
        const p = bay.parent
        return p && p.height > 1 ? p.height : 1080
    }
    readonly property real dockX: bay.viewW - bay.pad - bay.framePad - bay.dock
    readonly property real dockY: bay.viewH - bay.dock - bay.padY

    anchors.fill: parent
    opacity: (bay.paused && !bay.lifted) ? 0 : bay.appear
    visible: opacity > 0.02

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    TextInput {
        id: box
        x: machine.x + machine.width * 0.5
        y: machine.y + machine.height * 0.5
        width: 1
        height: 1
        opacity: 0
        color: "transparent"
        cursorVisible: false
        enabled: bay.armed && bay.mode === "search"
        onEnabledChanged: {
            if (box.enabled)
                box.forceActiveFocus()
            else
                box.text = ""
        }
        onTextChanged: {
            if (bay.query === box.text)
                return
            bay.query = box.text
            if (bay.armed && bay.mode === "search")
                bay.syncHits()
        }
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Up) {
                bay.pick(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                bay.pick(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                bay.confirm()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                Command.dismiss()
                event.accepted = true
            }
        }
    }

    function wakePower(): void {
        retract.stop()
        stirAnim.stop()
        const already = bay.armed
        bay.mode = "power"
        bay.armed = true
        bay.selected = 0
        bay.locked = false
        bay.clearSearch()
        if (already) {
            bay.stir()
            return
        }
        veilIn.restart()
        heatUp.restart()
        machine.burst()
        machine.rollMarks()
    }

    function wakeSearch(): void {
        retract.stop()
        stirAnim.stop()
        const already = bay.armed
        bay.mode = "search"
        bay.armed = true
        bay.selected = 0
        bay.locked = false
        bay.clearSearch()
        box.text = ""
        box.forceActiveFocus()
        if (already) {
            bay.stir()
            return
        }
        veilIn.restart()
        heatUp.restart()
        machine.burst()
        machine.rollMarks()
    }

    function sleep(): void {
        if (!bay.lifted)
            return
        heatUp.stop()
        stirAnim.stop()
        veilIn.stop()
        bay.killSearch()
        bay.armed = false
        machine.clearMarks()
        retract.restart()
    }

    function clearSearch(): void {
        seekModel.clear()
        bay.query = ""
        bay.selectedId = ""
        bay.selectedName = ""
        bay.seekLive = 0
    }

    function killSearch(): void {
        for (let i = 0; i < seekModel.count; i++)
            seekModel.setProperty(i, "dying", true)
    }

    function tallyLive(): void {
        let n = 0
        for (let i = 0; i < seekModel.count; i++) {
            if (!seekModel.get(i).dying)
                n += 1
        }
        bay.seekLive = n
    }

    function findRow(id: string): int {
        for (let i = 0; i < seekModel.count; i++) {
            if (seekModel.get(i).appId === id)
                return i
        }
        return -1
    }

    function liveRow(id: string): int {
        const i = bay.findRow(id)
        if (i < 0)
            return -1
        if (seekModel.get(i).dying)
            return -1
        return i
    }

    function pullName(): void {
        const i = bay.liveRow(bay.selectedId)
        bay.selectedName = i >= 0 ? String(seekModel.get(i).name || "") : ""
    }

    function reselect(): void {
        if (bay.liveRow(bay.selectedId) >= 0) {
            bay.pullName()
            return
        }
        let best = ""
        let bestSlot = 99
        for (let i = 0; i < seekModel.count; i++) {
            const row = seekModel.get(i)
            if (row.dying)
                continue
            if (row.slot < bestSlot) {
                bestSlot = row.slot
                best = row.appId
            }
        }
        bay.selectedId = best
        bay.pullName()
    }

    function syncHits(): void {
        if (!bay.armed || bay.mode !== "search")
            return
        const next = bay.query.length ? Apps.top(bay.query, 5) : []
        const keep = ({})
        for (let n = 0; n < next.length; n++)
            keep[next[n].id] = next[n]

        for (let i = 0; i < seekModel.count; i++) {
            const row = seekModel.get(i)
            if (!keep[row.appId])
                seekModel.setProperty(i, "dying", true)
        }

        for (let n = 0; n < next.length; n++) {
            const h = next[n]
            const i = bay.findRow(h.id)
            if (i >= 0) {
                seekModel.setProperty(i, "slot", n)
                seekModel.setProperty(i, "dying", false)
                seekModel.setProperty(i, "name", h.name)
                seekModel.setProperty(i, "icon", h.icon)
                seekModel.setProperty(i, "glyph", h.glyph)
            } else {
                seekModel.append({
                    appId: h.id,
                    name: h.name,
                    icon: h.icon,
                    glyph: h.glyph,
                    slot: n,
                    dying: false
                })
            }
        }
        bay.reselect()
        bay.tallyLive()
        machine.burst()
        machine.rollMarks()
    }

    function dropSlab(id: string): void {
        const i = bay.findRow(id)
        if (i < 0)
            return
        if (!seekModel.get(i).dying)
            return
        seekModel.remove(i)
        bay.tallyLive()
        if (bay.selectedId === id)
            bay.reselect()
    }

    function pick(dir: int): void {
        if (!bay.armed)
            return
        if (bay.mode === "search") {
            const rows = []
            for (let i = 0; i < seekModel.count; i++) {
                const row = seekModel.get(i)
                if (row.dying)
                    continue
                rows.push({
                    id: row.appId,
                    slot: row.slot
                })
            }
            if (!rows.length)
                return
            rows.sort(function (a, b) {
                return a.slot - b.slot
            })
            let at = 0
            for (let i = 0; i < rows.length; i++) {
                if (rows[i].id === bay.selectedId) {
                    at = i
                    break
                }
            }
            const next = rows[(at + dir + rows.length) % rows.length]
            if (next.id === bay.selectedId)
                return
            bay.selectedId = next.id
            bay.pullName()
            bay.stir()
            return
        }
        if (bay.fire < 0.6)
            return
        const n = bay.slabCount
        const next = (bay.selected + dir + n) % n
        if (next === bay.selected)
            return
        bay.selected = next
        bay.stir()
    }

    function focusAt(i: int): void {
        if (!bay.armed || bay.mode !== "power" || bay.fire < 0.6)
            return
        if (i < 0 || i >= bay.slabCount || i === bay.selected)
            return
        bay.selected = i
        bay.stir()
    }

    function focusApp(id: string): void {
        if (!bay.armed || bay.mode !== "search")
            return
        if (bay.liveRow(id) < 0 || id === bay.selectedId)
            return
        bay.selectedId = id
        bay.pullName()
        bay.stir()
    }

    function confirm(): void {
        if (!bay.armed)
            return
        if (bay.mode === "search") {
            const i = bay.liveRow(bay.selectedId)
            if (i < 0)
                return
            const id = seekModel.get(i).appId
            Command.dismiss()
            Apps.launch(id)
            return
        }
        if (bay.fire < 0.8)
            return
        const act = bay.powerActs[bay.selected]
        if (!act)
            return
        Command.dismiss()
        Quickshell.execDetached([bay.powerSh, act.arg])
    }

    function stir(): void {
        if (!bay.armed)
            return
        machine.rollMarks()
    }

    Canvas {
        id: dim
        z: 0
        x: machine.x - 240
        y: machine.y + 10 - (bay.slabCount + 1) * 72 - 320
        width: machine.width + 480
        height: machine.y + machine.height + 180 - dim.y
        opacity: bay.veil
        visible: opacity > 0.02
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onXChanged: requestPaint()
        onYChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width * 0.5
            const hubY = machine.y - dim.y + machine.height * 0.5
            const cy = hubY - 240
            const rx = width * 0.48
            const ry = height * 0.54
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(rx / ry, 1)
            const g = ctx.createRadialGradient(0, 0, 28, 0, 0, ry)
            g.addColorStop(0, "rgba(0,0,0,0.68)")
            g.addColorStop(0.48, "rgba(0,0,0,0.42)")
            g.addColorStop(0.78, "rgba(0,0,0,0.12)")
            g.addColorStop(1, "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(0, 0, ry, 0, Math.PI * 2)
            ctx.fillStyle = g
            ctx.fill()
            ctx.restore()
        }
    }

    Machine {
        id: machine
        x: bay.dockX
        y: bay.dockY
        width: bay.dock
        height: bay.dock
        paused: (bay.paused && !bay.lifted) || bay.appear < 0.02
        boot: bay.boot
        heat: bay.heat
        locked: bay.locked
        accentOut: bay.mode === "search" ? bay.fire : 0
        liveSig: "101000"
        z: 2
    }

    Item {
        id: seekMark
        x: machine.x
        y: machine.y
        width: machine.width
        height: machine.height
        z: 4
        visible: bay.mode === "search" && (bay.query.length > 0 || seekMark.ghostFade > 0.02)

        property string shown: ""
        property string ghostCh: ""
        property int lastLen: 0
        property real ghostScale: 1
        property real ghostFade: 0
        readonly property int wordPx: bay.query.length <= 1 ? 78 : (bay.query.length <= 3 ? 42 : (bay.query.length <= 6 ? 26 : 18))

        Row {
            anchors.centerIn: parent
            spacing: seekMark.shown.length <= 1 ? 2 : 3

            Repeater {
                model: seekMark.shown.length

                Item {
                    id: cell
                    required property int index
                    readonly property string ch: seekMark.shown.charAt(cell.index)

                    width: fill.implicitWidth
                    height: fill.implicitHeight

                    Text {
                        anchors.centerIn: parent
                        text: cell.ch
                        color: Theme.warn
                        font.family: Theme.fontHud
                        font.pixelSize: seekMark.wordPx + 5
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                    }

                    Text {
                        id: fill
                        anchors.centerIn: parent
                        text: cell.ch
                        color: Theme.bg
                        font.family: Theme.fontHud
                        font.pixelSize: seekMark.wordPx
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        style: Text.Outline
                        styleColor: Theme.warn
                    }
                }
            }
        }

        Item {
            id: ghost
            anchors.centerIn: parent
            width: ghostFill.implicitWidth
            height: ghostFill.implicitHeight
            z: 5
            scale: seekMark.ghostScale
            opacity: seekMark.ghostFade
            visible: opacity > 0.02
            transformOrigin: Item.Center

            Text {
                anchors.centerIn: parent
                text: seekMark.ghostCh
                color: Theme.warn
                font.family: Theme.fontHud
                font.pixelSize: 83
                font.bold: true
                font.capitalization: Font.AllUppercase
            }

            Text {
                id: ghostFill
                anchors.centerIn: parent
                text: seekMark.ghostCh
                color: Theme.bg
                font.family: Theme.fontHud
                font.pixelSize: 78
                font.bold: true
                font.capitalization: Font.AllUppercase
                style: Text.Outline
                styleColor: Theme.warn
            }
        }

        SequentialAnimation {
            id: seekPunch
            PropertyAction {
                target: seekMark
                property: "ghostScale"
                value: 1.85
            }
            PropertyAction {
                target: seekMark
                property: "ghostFade"
                value: 1
            }
            NumberAnimation {
                target: seekMark
                property: "ghostScale"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: seekMark
                property: "ghostFade"
                to: 0
                duration: 90
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: seekMark.shown = bay.query
            }
        }

        Connections {
            target: bay
            function onQueryChanged() {
                const n = bay.query.length
                const grew = n > seekMark.lastLen
                seekMark.lastLen = n
                if (bay.mode !== "search")
                    return
                if (!grew || n < 1) {
                    seekPunch.stop()
                    seekMark.ghostFade = 0
                    seekMark.shown = bay.query
                    return
                }
                seekMark.shown = bay.query.slice(0, -1)
                seekMark.ghostCh = bay.query.charAt(n - 1)
                seekPunch.restart()
            }
        }
    }

    Text {
        id: seekName
        visible: bay.mode === "search" && bay.selectedName.length > 0
        x: machine.x
        y: machine.y + 10 - 72 - bay.seekLift + 86
        width: machine.width
        z: 3
        text: "// " + bay.selectedName + " //"
        color: Theme.line
        font.family: Theme.fontMono
        font.pixelSize: 12
        font.letterSpacing: 1.8
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    ListModel {
        id: seekModel
    }

    Repeater {
        model: bay.mode === "power" ? bay.slabCount : 0

        SlabFrame {
            required property int index
            readonly property real unit: Math.max(0, Math.min(1, (bay.fire - index * 0.1) / 0.58))
            readonly property real ease: unit * unit * (3 - 2 * unit)
            readonly property real destY: machine.y + 10 - (index + 1) * 72
            readonly property real originY: machine.y + 108

            x: machine.x + (machine.width - width) * 0.5
            y: originY + (destY - originY) * ease
            z: 1
            reveal: ease
            iconSrc: {
                const act = bay.powerActs[index]
                return act ? Qt.resolvedUrl(act.icon) : ""
            }
            tag: ""
            lit: bay.armed && index === bay.selected
            onHovered: bay.focusAt(index)
            onActivated: {
                bay.selected = index
                bay.confirm()
            }
        }
    }

    Repeater {
        model: seekModel

        SearchSlab {
            x: machine.x + (machine.width - width) * 0.5
            originY: machine.y + 108
            destY: machine.y + 10 - (slot + 1) * 72 - bay.seekLift
            lit: bay.armed && !dying && appId === bay.selectedId
            onHovered: bay.focusApp(appId)
            onActivated: {
                bay.selectedId = appId
                bay.pullName()
                bay.confirm()
            }
            onGone: bay.dropSlab(appId)
        }
    }

    Component.onCompleted: intro.start()

    NumberAnimation {
        id: veilIn
        target: bay
        property: "veil"
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: intro
        PauseAnimation {
            duration: 80
        }
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "appear"
                to: 1
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: bay
                property: "boot"
                to: 1
                duration: 520
                easing.type: Easing.Linear
            }
        }
    }

    SequentialAnimation {
        id: heatUp
        NumberAnimation {
            target: bay
            property: "heat"
            to: 1
            duration: 70
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 110
        }
        ScriptAction {
            script: bay.locked = true
        }
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "fire"
                to: 1
                duration: 560
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: bay
                    property: "heat"
                    to: 0
                    duration: 180
                    easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: bay.locked = false
                }
            }
        }
    }

    SequentialAnimation {
        id: stirAnim
        PauseAnimation {
            duration: 70
        }
        ScriptAction {
            script: bay.locked = true
        }
        NumberAnimation {
            target: bay
            property: "heat"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: bay.locked = false
        }
    }

    SequentialAnimation {
        id: retract
        ParallelAnimation {
            NumberAnimation {
                target: bay
                property: "fire"
                to: 0
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: bay
                property: "veil"
                to: 0
                duration: 260
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: bay.locked = false
        }
        NumberAnimation {
            target: bay
            property: "heat"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                if (!bay.armed)
                    bay.mode = ""
            }
        }
    }
}
