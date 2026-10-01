import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Commons"

PanelWindow {
    id: window
    property Item anchorItem: null
    property var owner: null
    property var bar: null
    property bool open: false
    property real contentWidth: 320
    property real contentHeight: 320
    property int cardWidth: Math.round(contentWidth) + padding * 2
    property int cardHeight: Math.round(contentHeight) + padding * 2
    property int gap: 8
    property int screenMargin: 8
    property int padding: 12
    property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
    property Item focusTarget: null

    signal closeRequested()

    readonly property bool hovered: false
    default property alias content: holder.children

    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property real barW: anchorWindow ? anchorWindow.width : 0
    readonly property real barH: anchorWindow ? anchorWindow.height : 0
    readonly property real screenW: screen ? screen.width : 0
    readonly property real screenH: screen ? screen.height : 0

    function fittedContentWidth(w) {
        return Math.round(w);
    }

    function fittedContentHeight(h, maxH) {
        var available = screenH > 0 ? (screenH - (barH + gap + screenMargin * 2 + padding * 2)) : 600;
        var limit = maxH > 0 ? Math.min(maxH, available) : available;
        return Math.round(Math.min(Math.max(h, 100), limit));
    }

    TransformWatcher {
        id: anchorWatcher
        a: window.anchorWindow ? window.anchorWindow.contentItem : null
        b: window.anchorItem
    }

    readonly property point anchorPos: {
        anchorWatcher.transform
        if (!anchorItem || !anchorWindow) return Qt.point(0, 0)
        return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
    }

    readonly property point cardOrigin: {
        if (!anchorItem || !anchorWindow) return Qt.point(screenMargin, screenMargin)
        var x = anchorPos.x + anchorItem.width / 2 - cardWidth / 2
        var y = barH + gap
        x = Math.max(screenMargin, Math.min(x, screenW - cardWidth - screenMargin))
        y = Math.max(screenMargin, Math.min(y, screenH - cardHeight - screenMargin))
        return Qt.point(Math.round(x), Math.round(y))
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    implicitWidth: cardWidth
    implicitHeight: cardHeight

    anchors {
        top: true
        left: true
    }

    margins {
        top: window.cardOrigin.y
        left: window.cardOrigin.x
    }

    onOpenChanged: {
        if (!open || !focusTarget) return;
        Qt.callLater(function() {
            if (window.open && window.focusTarget) {
                window.focusTarget.forceActiveFocus();
            }
        });
    }

    BorderSurface {
        id: surface
        anchors.fill: parent
        color: Color.popups.background
        borderSpec: window.borderSpec
        padding: window.padding
        radius: Style.cornerRadius

        Item {
            id: holder
            anchors.fill: parent
            anchors.margins: window.padding
        }
    }
}
