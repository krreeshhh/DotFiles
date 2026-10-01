import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."

PanelWindow {
    id: popup

    property Item anchorItem: null
    property var bar: null

    property bool open: false
    property int cardWidth: 340
    property int cardHeight: 320
    property int gap: 8
    property int screenMargin: 8
    property int padding: 12
    property color borderColor: Theme.popupBorder
    property Item focusTarget: null

    signal closeRequested()

    readonly property bool hovered: cardHover.hovered

    default property alias content: holder.children

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property real barW: anchorWindow ? anchorWindow.width : 0
    readonly property real barH: anchorWindow ? anchorWindow.height : 0
    readonly property real screenW: screen ? screen.width : 0
    readonly property real screenH: screen ? screen.height : 0
    readonly property real contentInset: padding * 2 + 2

    function fittedHeight(contentHeight, cap) {
        var desired = Math.max(contentInset, (Number(contentHeight) || 0) + contentInset)
        var maxHeight = screenH > 0 ? Math.max(120, screenH - (barH + gap + screenMargin)) : desired
        if (cap !== undefined && Number(cap) > 0)
            maxHeight = Math.min(maxHeight, Number(cap))
        return Math.round(Math.min(desired, maxHeight))
    }

    TransformWatcher {
        id: anchorWatcher
        a: popup.anchorWindow ? popup.anchorWindow.contentItem : null
        b: popup.anchorItem
    }

    readonly property point anchorPos: {
        anchorWatcher.transform
        if (!anchorItem || !anchorWindow)
            return Qt.point(0, 0)
        return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
    }

    readonly property point cardOrigin: {
        if (!anchorItem || !anchorWindow)
            return Qt.point(screenMargin, screenMargin)
        var x = anchorPos.x + anchorItem.width / 2 - cardWidth / 2
        var y = barH + gap
        x = Math.max(screenMargin, Math.min(x, screenW - cardWidth - screenMargin))
        y = Math.max(screenMargin, Math.min(y, screenH - cardHeight - screenMargin))
        return Qt.point(Math.round(x), Math.round(y))
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open || card.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-ledge"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    implicitWidth: cardWidth
    implicitHeight: cardHeight

    anchors {
        top: true
        left: true
    }

    margins {
        top: popup.cardOrigin.y
        left: popup.cardOrigin.x
    }

    onOpenChanged: {
        if (!open || !focusTarget)
            return
        Qt.callLater(function () {
            if (popup.open && popup.focusTarget)
                popup.focusTarget.forceActiveFocus()
        })
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.popupSurface
        border.color: popup.borderColor
        border.width: 1
        radius: 12
        opacity: popup.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
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
