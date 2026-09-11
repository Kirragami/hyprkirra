pragma ComponentBehavior: Bound

import Quickshell.Services.Notifications
import QtQuick

Item {
    id: bay

    readonly property int cardW: 476
    readonly property int cardH: 76
    readonly property int gap: 10
    readonly property int padY: 16
    readonly property int cap: 4
    readonly property int count: live.count
    readonly property int packH: stack.height + bay.padY
    readonly property int bayH: bay.cap * bay.cardH + Math.max(0, bay.cap - 1) * bay.gap + bay.padY

    property var store: ({})
    property int nextSid: 1

    implicitWidth: bay.cardW
    implicitHeight: bay.bayH

    function rewire(sid: string, n: var): void {
        const map = Object.assign({}, bay.store)
        map[String(sid)] = n
        bay.store = map
    }

    function dropSid(sid: string): void {
        const key = String(sid)
        const n = bay.store[key]
        if (n)
            n.tracked = false
        for (let i = 0; i < live.count; i++) {
            if (String(live.get(i).sid) === key) {
                live.remove(i)
                break
            }
        }
        const map = Object.assign({}, bay.store)
        delete map[key]
        bay.store = map
    }

    function ingest(n: var): void {
        if (!n)
            return
        for (let i = 0; i < stack.children.length; i++) {
            const card = stack.children[i]
            if (card.matches && card.matches(n)) {
                card.replaceWith(n)
                return
            }
        }
        const sid = String(bay.nextSid++)
        bay.rewire(sid, n)
        live.insert(0, {
            sid: sid
        })
        bay.trim()
    }

    function trim(): void {
        while (live.count > bay.cap) {
            const sid = String(live.get(live.count - 1).sid)
            bay.dropSid(sid)
        }
    }

    ListModel {
        id: live
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            if (n.lastGeneration)
                return
            n.tracked = true
            Qt.callLater(() => bay.ingest(n))
        }
    }

    Column {
        id: stack
        x: 0
        y: 8
        width: bay.cardW
        spacing: bay.gap

        Repeater {
            model: live

            Toast {
                id: card
                required property string sid

                notif: bay.store[sid]

                onHide: card.leave()
                onDone: bay.dropSid(card.sid)
                onSwapCommitted: n => bay.rewire(card.sid, n)
            }
        }
    }
}
