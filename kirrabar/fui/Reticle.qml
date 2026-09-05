import QtQuick

Item {
    id: reticle
    implicitWidth: 22
    implicitHeight: 22

    Rectangle {
        width: 18
        height: 18
        anchors.centerIn: parent
        rotation: 45
        color: "transparent"
        border.color: Theme.line
        border.width: 1

        RotationAnimation on rotation {
            from: 45
            to: 405
            duration: 14000
            loops: Animation.Infinite
        }
    }

    Rectangle {
        width: 22
        height: 1
        anchors.centerIn: parent
        color: Theme.line
        opacity: 0.35
    }

    Rectangle {
        width: 1
        height: 22
        anchors.centerIn: parent
        color: Theme.line
        opacity: 0.35
    }

    Rectangle {
        width: 5
        height: 5
        anchors.centerIn: parent
        rotation: 45
        color: Theme.line

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
    }
}
