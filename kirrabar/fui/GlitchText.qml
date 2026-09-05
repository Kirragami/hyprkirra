import QtQuick

Text {
    id: root

    property string value: ""
    property bool settled: false
    property bool glitchOnChange: false
    property int scrambleMs: 42

    property string _garbled: ""
    property string _shown: ""
    property bool _scrambling: false

    readonly property string glyphs: "ABCDEFGHKMNPQRSTUVWXYZ0123456789#/<>|¦■□▬▪"
    readonly property bool revealing: !root.settled || root._scrambling

    text: root.revealing ? root._garbled : (root._shown.length ? root._shown : root.value)
    font.family: Theme.fontMono

    function scramble(): void {
        const src = root._shown.length ? root._shown : root.value
        const len = Math.max(src.length, 3)
        let s = ""
        for (let i = 0; i < len; i++) {
            if (src.charAt(i) && Math.random() > 0.55)
                s += src.charAt(i)
            else
                s += root.glyphs.charAt(Math.floor(Math.random() * root.glyphs.length))
        }
        root._garbled = s
    }

    function kick(ms: int): void {
        if (root._scrambling)
            return
        root._scrambling = true
        root.scramble()
        relock.interval = ms > 0 ? ms : 110
        relock.restart()
    }

    function commit(): void {
        if (root.value === root._shown)
            return
        const prev = root._shown
        root._shown = root.value
        if (root.glitchOnChange && root.settled && prev.length > 0)
            root.kick(90)
    }

    onValueChanged: hold.restart()
    onSettledChanged: {
        if (root.settled)
            root.commit()
        else
            root.scramble()
    }

    Timer {
        id: hold
        interval: 140
        onTriggered: root.commit()
    }

    Timer {
        interval: root.scrambleMs
        running: root.revealing
        repeat: true
        onTriggered: root.scramble()
    }

    Timer {
        id: relock
        interval: 110
        onTriggered: root._scrambling = false
    }

    Component.onCompleted: {
        root._shown = root.value
        if (!root.settled)
            root.scramble()
    }
}
