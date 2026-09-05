import QtQuick
import "../fui"

Item {
    id: wipe
    property real progress: 0
    enabled: false

    readonly property int rows: 36

    Repeater {
        model: wipe.rows
        Rectangle {
            required property int index
            width: wipe.width
            height: wipe.height / wipe.rows + 1
            y: index * (wipe.height / wipe.rows)
            color: Theme.bg
            opacity: wipe.progress * wipe.rows > index ? 0 : 0.96
        }
    }

    Repeater {
        model: wipe.progress > 0 && wipe.progress < 1 ? 10 : 0
        Rectangle {
            required property int index
            width: 2 + Math.random() * 10
            height: 2
            x: Math.random() * Math.max(1, wipe.width)
            y: Math.min(wipe.height - 2, wipe.progress * wipe.height + (Math.random() - 0.5) * 12)
            color: Theme.line
            opacity: 0.45
        }
    }

    Rectangle {
        width: parent.width
        height: 2
        y: wipe.progress * parent.height
        color: Theme.line
        visible: wipe.progress > 0.02 && wipe.progress < 0.99
        opacity: 0.75
    }
}
