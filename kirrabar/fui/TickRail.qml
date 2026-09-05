import QtQuick

Item {
    id: rail
    property int tickCount: 72

    Row {
        id: topRow
        anchors.top: parent.top
        anchors.topMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 4

        Repeater {
            model: rail.tickCount
            Rectangle {
                required property int index
                width: 1
                height: index % 6 === 0 ? 5 : 2
                color: "#ffffff"
                opacity: index % 6 === 0 ? 0.35 : 0.12
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        spacing: 4

        Repeater {
            model: rail.tickCount
            Rectangle {
                required property int index
                width: 1
                height: index % 6 === 0 ? 5 : 2
                color: "#ffffff"
                opacity: index % 6 === 0 ? 0.28 : 0.1
            }
        }
    }

    Rectangle {
        id: traveler
        width: 7
        height: 2
        y: 3
        color: "#ffffff"
        opacity: 0.7

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation {
                from: 28
                to: Math.max(36, rail.width - 36)
                duration: 9000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: Math.max(36, rail.width - 36)
                to: 28
                duration: 9000
                easing.type: Easing.InOutSine
            }
        }
    }
}
