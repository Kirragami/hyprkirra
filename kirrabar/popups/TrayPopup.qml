pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 360
    paneHeight: Math.min(440, Math.max(148, 52 + itemsCol.implicitHeight))

    property var menuHandle: null
    property var _stack: []
    property var holdList: []

    readonly property var currentHandle: pop._stack.length > 0 ? pop._stack[pop._stack.length - 1] : pop.menuHandle

    Instantiator {
        model: pop.holdList
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
    }

    QsMenuOpener {
        id: opener
        menu: pop.currentHandle
    }

    onMenuHandleChanged: {
        pop._stack = []
        pop.syncHold()
        if (pop.open)
            pop.kick()
    }

    function syncHold(): void {
        const list = []
        if (pop.menuHandle)
            list.push(pop.menuHandle)
        for (let i = 0; i < pop._stack.length; i++)
            list.push(pop._stack[i])
        pop.holdList = list
    }

    function pushMenu(entry: var): void {
        if (!entry)
            return
        const next = pop._stack.slice()
        next.push(entry)
        pop._stack = next
        pop.syncHold()
        pop.kick()
    }

    function popMenu(): void {
        if (pop._stack.length === 0)
            return
        const next = pop._stack.slice()
        next.pop()
        pop._stack = next
        pop.syncHold()
        pop.kick()
    }

    Item {
        anchors.fill: parent

        Column {
            id: head
            width: parent.width
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Text {
                    visible: pop._stack.length > 0
                    text: "‹"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.popMenu()
                    }
                }

                GlitchText {
                    value: pop._stack.length > 0 ? "APP // SUB" : "APP // MENU"
                    settled: true
                    color: Theme.textMute
                    font.family: Theme.fontHud
                    font.pixelSize: 10
                    font.letterSpacing: 1.8
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.lineFaint
            }
        }

        Flickable {
            id: scroller
            anchors.top: head.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: itemsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height + 1

            Column {
                id: itemsCol
                width: scroller.width
                spacing: 4

                Repeater {
                    model: opener.children

                    HudRow {
                        required property var modelData
                        width: itemsCol.width
                        separator: modelData.isSeparator
                        label: modelData.text || ""
                        icon: modelData.icon || ""
                        enabled: !modelData.isSeparator && (modelData.enabled || modelData.hasChildren)
                        chevron: modelData.hasChildren
                        checked: modelData.checkState === Qt.Checked
                        onClicked: {
                            if (modelData.isSeparator)
                                return
                            if (modelData.hasChildren) {
                                pop.pushMenu(modelData)
                                return
                            }
                            modelData.triggered()
                            pop.dismiss()
                        }
                    }
                }

                Text {
                    visible: opener.children.values.length === 0
                    text: "NO ACTIONS"
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }
        }
    }
}
