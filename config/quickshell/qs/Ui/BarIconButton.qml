import QtQuick
import "../Commons"

Rectangle {
    id: root
    property var bar: null
    property var iconComponent: null
    property string tooltipText: ""
    property color activeColor: Color.accent
    property color foreground: Color.foreground
    property bool active: false
    property bool dimmed: false
    property int opticalSize: 26
    property int slotSize: 26

    signal pressed(int buttonCode)
    signal clicked()

    implicitWidth: slotSize > 0 ? slotSize : 26
    implicitHeight: 36
    radius: 6
    color: active ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : (mouse.containsMouse ? Color.popups.background : "transparent")
    opacity: dimmed ? 0.6 : 1.0

    Loader {
        anchors.centerIn: parent
        sourceComponent: root.iconComponent
        width: root.opticalSize > 0 ? root.opticalSize : 18
        height: root.opticalSize > 0 ? root.opticalSize : 18
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: mouseEvent => root.pressed(mouseEvent.button)
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.LeftButton) root.clicked();
        }
    }
}
