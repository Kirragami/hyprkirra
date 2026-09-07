import QtQuick
import "svc"

Item {
    id: frame

    default property alias content: body.data

    property real arm: 15
    property real thick: 1.15
    property real inset: 4
    property real pad: 10
    property color color: Theme.line
    property real lineAlpha: 0.82

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: frame.pad
    }

    Repeater {
        model: 4

        Item {
            required property int index
            width: frame.arm
            height: frame.arm
            x: index === 1 || index === 3 ? frame.width - width : 0
            y: index === 2 || index === 3 ? frame.height - height : 0
            opacity: frame.lineAlpha

            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index === 2 || index === 3

            Rectangle {
                width: parent.width
                height: frame.thick
                color: frame.color
                y: parent.atBottom ? parent.height - height : 0
            }

            Rectangle {
                width: frame.thick
                height: parent.height
                color: frame.color
                x: parent.atRight ? parent.width - width : 0
            }

            Rectangle {
                width: Math.max(frame.thick, frame.arm - frame.inset - 2)
                height: frame.thick
                color: Theme.lineDim
                opacity: 0.7
                x: parent.atRight ? parent.width - width - frame.inset : frame.inset
                y: parent.atBottom ? parent.height - height - frame.inset : frame.inset
            }

            Rectangle {
                width: frame.thick
                height: Math.max(frame.thick, frame.arm - frame.inset - 2)
                color: Theme.lineDim
                opacity: 0.7
                x: parent.atRight ? parent.width - width - frame.inset : frame.inset
                y: parent.atBottom ? parent.height - height - frame.inset : frame.inset
            }
        }
    }
}
