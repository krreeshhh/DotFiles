import QtQuick
import "../Commons"

Item {
    id: toggle
    property string label: ""
    property string description: ""
    property bool checked: false
    property bool hasCursor: false
    property color foreground: Color.foreground
    property color accent: Color.accent
    property string fontFamily: Style.font.family

    signal clicked()
    signal hovered(bool hovered)

    implicitWidth: parent ? parent.width : 200
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 6
        color: toggle.hasCursor ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : "transparent"
        visible: toggle.hasCursor
    }

    Row {
        anchors.fill: parent
        spacing: 10

        Column {
            width: parent.width - 50
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: toggle.label
                color: toggle.foreground
                font.family: toggle.fontFamily
                font.pixelSize: 12
            }
            Text {
                visible: toggle.description !== ""
                text: toggle.description
                color: Color.muted
                font.family: toggle.fontFamily
                font.pixelSize: 10
            }
        }

        Rectangle {
            width: 36
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: toggle.checked ? toggle.accent : Color.popups.background
            border.color: Color.popups.border
            border.width: 1

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: toggle.checked ? 18 : 2
                color: toggle.foreground

                Behavior on x {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: toggle.hovered(true)
        onExited: toggle.hovered(false)
        onClicked: toggle.clicked()
    }
}
