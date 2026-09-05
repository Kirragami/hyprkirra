import QtQuick

Item {
    id: root

    default property alias content: scene.data

    property bool autoPlay: false
    property bool open: true
    property bool manageVisibility: false
    property int duration: 280
    property real intensity: 0.55
    property int slices: 5

    readonly property bool glitching: root._glitch

    signal finished()

    property bool _glitch: false
    property var _off: []
    property var _noise: []
    property real _flash: 0
    property real _jitter: 0
    property bool _ready: false

    clip: true

    function play(ms: int): void {
        if (ms !== undefined && ms > 0)
            root.duration = ms
        root._glitch = true
        root.reshuffle()
        tick.restart()
        halt.interval = root.duration
        halt.restart()
    }

    function reshuffle(): void {
        const o = []
        const amp = 4 + 10 * root.intensity
        const tear = Math.floor(Math.random() * root.slices)
        for (let i = 0; i < root.slices; i++) {
            const hit = i === tear || Math.random() > 0.78
            o.push(hit ? (Math.random() - 0.5) * 2 * amp : 0)
        }
        root._off = o

        const n = []
        const count = Math.floor(Math.random() * 2)
        for (let i = 0; i < count; i++) {
            n.push({
                x: Math.random() * Math.max(1, root.width),
                y: Math.random() * Math.max(1, root.height),
                w: 8 + Math.random() * 28,
                h: 1 + Math.random() * 2,
                white: true
            })
        }
        if (Math.random() > 0.45) {
            n.push({
                x: 0,
                y: Math.random() * Math.max(1, root.height),
                w: root.width,
                h: 1,
                white: true
            })
        }
        root._noise = n
        root._flash = Math.random() > 0.88 ? (0.04 + Math.random() * 0.06) : 0
        root._jitter = (Math.random() - 0.5) * 3 * root.intensity
    }

    onOpenChanged: {
        if (!root._ready)
            return
        if (root.open) {
            root.visible = true
            root.play(root.duration)
        } else {
            root.play(Math.min(root.duration, 140))
        }
    }

    Component.onCompleted: {
        root._ready = true
        if (root.autoPlay)
            root.play(root.duration)
    }

    Timer {
        id: tick
        interval: 48
        running: root._glitch
        repeat: true
        onTriggered: root.reshuffle()
    }

    Timer {
        id: halt
        interval: 280
        onTriggered: {
            root._glitch = false
            scene.visible = true
            root._flash = 0
            root._jitter = 0
            root._noise = []
            if (!root.open && root.manageVisibility)
                root.visible = false
            root.finished()
        }
    }

    transform: Translate {
        x: root._jitter
    }

    Item {
        id: scene
        anchors.fill: parent
    }

    Repeater {
        model: root._glitch ? root.slices : 0

        ShaderEffectSource {
            required property int index
            sourceItem: scene
            live: true
            hideSource: false
            sourceRect: Qt.rect(
                0,
                index * (root.height / Math.max(1, root.slices)),
                root.width,
                root.height / Math.max(1, root.slices) + 1
            )
            x: (root._off[index] || 0)
            y: index * (root.height / Math.max(1, root.slices))
            width: root.width
            height: root.height / Math.max(1, root.slices) + 1
        }
    }

    Repeater {
        model: root._noise

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: modelData.white ? Theme.line : Theme.bg
            opacity: modelData.white ? 0.28 : 0.5
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.line
        opacity: root._flash
        visible: root._flash > 0.01
    }
}
