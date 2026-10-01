import QtQuick
import "../Commons"

Rectangle {
    id: button
    property var bar: null
    property bool labelVisible: false
    property bool hasVisualContent: true
    property bool dimmed: false
    property string tooltipText: ""
    property int fixedWidth: -1
    property int fixedHeight: -1
    property color activeColor: Color.accent
    property color foreground: Color.foreground

    signal pressed(int buttonCode)
    signal clicked()

    implicitWidth: fixedWidth > 0 ? fixedWidth : (childrenRect.width + 12)
    implicitHeight: fixedHeight > 0 ? fixedHeight : 36
    radius: 6
    color: mouse.containsMouse ? Color.popups.background : "transparent"

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouseEvent => button.pressed(mouseEvent.button)
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.LeftButton) button.clicked();
        }
    }
}
