import QtQuick

Item {
    id: root

    property bool selected: false
    property real zoom: Theme.pickZoom
    property real lockPad: 8

    clip: false
    scale: root.selected ? root.zoom : 1
    transformOrigin: Item.Center

    readonly property real lockInner: Theme.lockInner(width, height, root.lockPad)
    readonly property real lockR: Theme.lockR(width, height, root.lockPad)

    Behavior on scale {
        NumberAnimation { duration: Theme.zoomMs; easing.type: Easing.OutCubic }
    }
}
