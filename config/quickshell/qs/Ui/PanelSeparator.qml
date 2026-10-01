import QtQuick
import "../Commons"

Rectangle {
    id: sep
    property color foreground: Color.muted
    implicitWidth: parent ? parent.width : 200
    implicitHeight: 1
    color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
}
