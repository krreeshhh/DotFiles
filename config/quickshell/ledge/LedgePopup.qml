import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: popup

    property Item anchorItem: null
    property var bar: null

    property bool open: false
    property int cardWidth: 360
    property int cardHeight: 320
    property int padding: 14
    property color borderColor: Theme.popupBorder
    property Item focusTarget: null

    signal closeRequested()

    readonly property bool hovered: cardHover.hovered

    default property alias content: holder.children

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property real screenH: screen ? screen.height : 0
    readonly property real contentInset: padding * 2 + 2

    function fittedHeight(contentHeight, cap) {
        var desired = Math.max(contentInset, (Number(contentHeight) || 0) + contentInset)
        var maxHeight = screenH > 0 ? Math.max(120, screenH - 56) : desired
        if (cap !== undefined && Number(cap) > 0)
            maxHeight = Math.min(maxHeight, Number(cap))
        return Math.round(Math.min(desired, maxHeight))
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open || card.opacity > 0
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: card }

    onOpenChanged: {
        if (!open || !focusTarget)
            return
        Qt.callLater(function () {
            if (popup.open && popup.focusTarget)
                popup.focusTarget.forceActiveFocus()
        })
    }

    // Full screen background dismisser (matches ControlCenter & BluetoothMenu)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        enabled: popup.open
        onClicked: popup.closeRequested()
    }

    Rectangle {
        id: card
        width: popup.cardWidth
        height: popup.cardHeight
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: 16
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1
        focus: true
        transformOrigin: Item.TopRight

        opacity: popup.open ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: popup.open ? 200 : 150
                easing.type: popup.open ? Easing.OutCubic : Easing.InQuad
            }
        }

        HoverHandler {
            id: cardHover
        }

        Item {
            id: holder
            anchors.fill: parent
            anchors.margins: popup.padding
        }
    }
}
