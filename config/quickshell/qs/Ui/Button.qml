import QtQuick
import "../Commons"

Rectangle {
    id: root

    property string iconText: ""
    property string text: ""
    property string tooltipText: ""
    property color foreground: Color.foreground
    property color background: "transparent"
    property color hoverBackground: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
    property color activeBackground: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
    property bool active: false
    property bool dimmed: false
    property bool bordered: false
    property int horizontalPadding: 6
    property int verticalPadding: 4
    property string fontFamily: Style.font.family
    property int iconSize: Style.font.icon
    property int fontSize: Style.font.bodySmall
    property alias pixelSize: root.iconSize

    signal clicked()

    implicitWidth: contentRow.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(28, contentRow.implicitHeight + verticalPadding * 2)

    radius: 6
    color: mouse.pressed ? activeBackground : (mouse.containsMouse ? hoverBackground : (active ? activeBackground : background))
    border.width: bordered ? 1 : 0
    border.color: active ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2)

    Behavior on color { ColorAnimation { duration: 80 } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            font.family: root.fontFamily
            font.pixelSize: root.iconSize
            color: root.dimmed ? Color.muted : root.foreground
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text.length > 0
            text: root.text
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            color: root.dimmed ? Color.muted : root.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
