import QtQuick
import "../.."

Rectangle {
    id: button

    property alias icon: label.text
    property string tooltip: ""
    property string tooltipEdge: "bottom"
    property var theme: null
    property bool danger: false
    property bool active: false

    signal clicked()

    implicitWidth: 26
    implicitHeight: 26
    radius: width / 2
    readonly property bool lit: mouse.containsMouse || button.active

    color: button.lit
           ? (button.danger ? Qt.rgba(1, 0.3, 0.3, 0.22) : (theme ? theme.raisedHover : "transparent"))
           : "transparent"

    Behavior on color {
        ColorAnimation { duration: 90 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: 14
        color: button.active ? (theme ? theme.accent : Theme.primary) : (button.lit ? (theme ? theme.text : Theme.colOnSurface) : (theme ? theme.muted : Theme.colOnSurfaceVariant))
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: button.clicked()
    }

    Rectangle {
        id: tip

        readonly property bool vertical: button.tooltipEdge === "top" || button.tooltipEdge === "bottom"

        visible: mouse.containsMouse && button.tooltip !== ""
        anchors.horizontalCenter: tip.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: tip.vertical ? undefined : parent.verticalCenter
        anchors.bottom: button.tooltipEdge === "top" ? parent.top : undefined
        anchors.top: button.tooltipEdge === "bottom" ? parent.bottom : undefined
        anchors.right: button.tooltipEdge === "left" ? parent.left : undefined
        anchors.left: button.tooltipEdge === "right" ? parent.right : undefined
        anchors.margins: 4
        width: tooltipText.implicitWidth + 12
        height: tooltipText.implicitHeight + 8
        radius: 6
        color: theme ? theme.tooltipSurface : Theme.popupSurface
        border.width: 1
        border.color: theme ? theme.tooltipBorder : Theme.popupBorder
        z: 100

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: button.tooltip
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: theme ? theme.tooltipForeground : Theme.colOnSurface
        }
    }
}
