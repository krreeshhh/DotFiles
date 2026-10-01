import QtQuick
import "../Commons"

Rectangle {
    id: root
    property string label: ""
    property bool lit: false
    property string hint: ""

    signal activated()

    implicitWidth: labelText.implicitWidth + 12
    implicitHeight: 20
    radius: 4
    color: root.lit ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.10)
    border.width: 1
    border.color: root.lit ? Color.accent : Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.20)

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        color: root.lit ? Color.accent : Color.muted
        font.family: Style.font.family
        font.pixelSize: 9
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
