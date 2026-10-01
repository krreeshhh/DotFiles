import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Commons"

PopupWindow {
    id: root

    property var anchorItem: null
    property var bar: null
    property var owner: null
    property bool open: false
    property int contentWidth: 300
    property int contentHeight: 200

    function fittedContentWidth(w) { return Math.max(100, w); }
    function fittedContentHeight(h) { return Math.max(50, h); }

    visible: open
    implicitWidth: contentWidth + 24
    implicitHeight: contentHeight + 24
    color: "transparent"

    default property alias contentData: cardContent.data

    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Color.popups.background
        border.color: Color.popups.border
        border.width: 1

        Item {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 12
        }
    }
}
