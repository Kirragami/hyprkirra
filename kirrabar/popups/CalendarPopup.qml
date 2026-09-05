import Quickshell
import QtQuick
import "../fui"

HudPopup {
    id: pop
    paneWidth: 328
    paneHeight: 348

    SystemClock {
        id: sys
        precision: SystemClock.Seconds
    }

    readonly property var now: sys.date
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()

    readonly property var monthNames: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    readonly property var dow: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int lead: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int todayD: now.getDate()
    readonly property int todayM: now.getMonth()
    readonly property int todayY: now.getFullYear()

    function shift(delta: int): void {
        let m = pop.month + delta
        let y = pop.year
        if (m < 0) {
            m = 11
            y -= 1
        } else if (m > 11) {
            m = 0
            y += 1
        }
        pop.month = m
        pop.year = y
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: 18

            Text {
                text: "SYS // CLOCK"
                color: Theme.textMute
                font.family: Theme.fontHud
                font.pixelSize: 10
                font.letterSpacing: 1.8
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    width: 16
                    height: 16
                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.shift(-1)
                    }
                }

                Text {
                    width: 92
                    text: pop.monthNames[pop.month] + " " + pop.year
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    height: 16
                }

                Item {
                    width: 16
                    height: 16
                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.shift(1)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineFaint
        }

        Row {
            width: parent.width
            Repeater {
                model: pop.dow
                Text {
                    required property string modelData
                    required property int index
                    width: parent.width / 7
                    height: 14
                    text: modelData
                    color: Theme.textMute
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: 7
            rowSpacing: 3
            columnSpacing: 3

            Repeater {
                model: 42
                Rectangle {
                    required property int index
                    readonly property int day: index - pop.lead + 1
                    readonly property bool valid: day >= 1 && day <= pop.daysInMonth
                    readonly property bool today: valid && day === pop.todayD && pop.month === pop.todayM && pop.year === pop.todayY

                    width: (grid.width - 18) / 7
                    height: 32
                    color: today ? Theme.line : "transparent"
                    border.color: valid ? Theme.lineFaint : "transparent"
                    border.width: 1
                    opacity: valid ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        text: valid ? day : ""
                        color: today ? Theme.ink : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.bold: today
                    }
                }
            }
        }

        Item { width: 1; height: 2 }

        Text {
            text: Qt.formatDateTime(pop.now, "HH:mm:ss  ·  ddd").toUpperCase()
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.letterSpacing: 1.2
        }
    }
}
