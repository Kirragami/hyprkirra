import QtQuick
import "../fui"

Item {
    id: row
    property string label: ""
    property string hint: ""
    property string icon: ""
    property bool active: false
    property bool enabled: true
    property bool separator: false
    property bool chevron: false
    property bool checked: false

    signal clicked()

    implicitWidth: 280
    implicitHeight: separator ? 10 : 34
    opacity: enabled ? 1 : 0.38

    Rectangle {
        visible: row.separator
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Theme.lineFaint
    }

    Rectangle {
        visible: !row.separator
        anchors.fill: parent
        color: row.active ? Theme.line : (hover.containsMouse ? Theme.bgRaised : "transparent")
        border.color: hover.containsMouse || row.active ? Theme.lineDim : "transparent"
        border.width: 1
    }

    Item {
        visible: !row.separator
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        Rectangle {
            id: pip
            width: 5
            height: 5
            rotation: 45
            color: row.checked || row.active ? (row.active ? Theme.ink : Theme.line) : "transparent"
            border.color: Theme.lineDim
            border.width: 1
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Image {
            id: glyph
            visible: row.icon.length > 0
            source: row.icon
            width: 16
            height: 16
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            anchors.left: pip.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: hintMark
            visible: row.hint.length > 0 || row.chevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.chevron ? "›" : row.hint
            color: row.active ? Theme.ink : Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        Text {
            text: row.label
            color: row.active ? Theme.ink : Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 12
            elide: Text.ElideRight
            anchors.left: glyph.visible ? glyph.right : pip.right
            anchors.leftMargin: 8
            anchors.right: hintMark.visible ? hintMark.left : parent.right
            anchors.rightMargin: hintMark.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: !row.separator && row.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
