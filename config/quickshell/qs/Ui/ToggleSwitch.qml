import QtQuick
import "../Commons"

Item {
    id: root

    property bool checked: false
    property color foreground: Color.foreground
    property color accent: Color.accent
    property color background: Color.popups.background
    property color border: Color.popups.border

    signal toggled()
    signal clicked()

    implicitWidth: 36
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.checked ? root.accent : root.background
        border.color: root.border
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? Color.background : root.foreground

            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled();
            root.clicked();
        }
    }
}
