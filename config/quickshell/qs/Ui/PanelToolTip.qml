import QtQuick
import "../Commons"

Rectangle {
    id: tip
    property string text: ""
    property string fontFamily: Style.font.family
    property color foreground: Color.tooltip.text
    property color background: Color.tooltip.background
    property color borderColor: Color.tooltip.border

    visible: false
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.top: parent ? parent.bottom : undefined
    anchors.topMargin: 4
    width: label.implicitWidth + 12
    height: label.implicitHeight + 8
    radius: 6
    color: tip.background
    border.color: tip.borderColor
    border.width: 1
    z: 100

    Text {
        id: label
        anchors.centerIn: parent
        text: tip.text
        font.family: tip.fontFamily
        font.pixelSize: 11
        color: tip.foreground
    }
}
