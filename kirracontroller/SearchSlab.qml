pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: wrap

    required property int index
    required property string appId
    required property string name
    required property string icon
    required property string glyph
    required property int slot
    required property bool dying

    property bool lit: false
    property real originY: 0
    property real destY: 0
    property bool ready: false

    signal hovered()
    signal activated()
    signal gone()

    width: frame.width
    height: frame.height
    y: (wrap.dying || !wrap.ready) ? wrap.originY : wrap.destY
    z: 1

    Behavior on y {
        NumberAnimation {
            duration: 280
            easing.type: Easing.InOutCubic
        }
    }

    SlabFrame {
        id: frame
        reveal: (wrap.dying || !wrap.ready) ? 0 : 1
        lit: wrap.lit
        inkOnLit: false
        iconSrc: wrap.icon
        tag: wrap.glyph
        onHovered: wrap.hovered()
        onActivated: wrap.activated()
        onRevealChanged: {
            if (wrap.dying && frame.reveal < 0.02)
                wrap.gone()
        }

        Behavior on reveal {
            NumberAnimation {
                duration: 280
                easing.type: Easing.InOutCubic
            }
        }
    }

    Component.onCompleted: Qt.callLater(function () {
        wrap.ready = true
    })
}
