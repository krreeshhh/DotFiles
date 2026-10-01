import QtQuick
import "../Commons"

Item {
    id: header
    property string text: ""
    property color foreground: Color.muted
    property string fontFamily: Style.font.family

    implicitWidth: parent ? parent.width : 200
    implicitHeight: 20

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: header.text
        color: header.foreground
        font.family: header.fontFamily
        font.pixelSize: 10
        font.bold: true
    }
}
