import QtQuick
import "../.."

QtObject {
    id: theme

    readonly property color surface: Theme.popupSurface
    readonly property color text: Theme.colOnSurface
    readonly property color border: Theme.popupBorder
    readonly property color muted: Theme.colOnSurfaceVariant
    readonly property color accent: Theme.primary

    readonly property color tooltipSurface: Theme.popupSurface
    readonly property color tooltipForeground: Theme.colOnSurface
    readonly property color tooltipBorder: Theme.popupBorder

    readonly property color raised: Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color raisedHover: Qt.rgba(text.r, text.g, text.b, 0.16)
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.20)

    readonly property int radius: 10
    readonly property int spacing: 8
    readonly property int padding: 12
    readonly property string fontFamily: Theme.fontFamily
}
