import QtQuick

pragma Singleton

QtObject {
    id: color

    readonly property color foreground: typeof Theme !== "undefined" ? Theme.colOnSurface : "#ffffff"
    readonly property color background: typeof Theme !== "undefined" ? Theme.background : "#130f12"
    readonly property color accent: typeof Theme !== "undefined" ? Theme.primary : "#e183c2"
    readonly property color muted: typeof Theme !== "undefined" ? Theme.colOnSurfaceVariant : "#a5a5aa"
    readonly property color urgent: typeof Theme !== "undefined" ? Theme.colorError : "#ff6b6b"

    function flatColor(col) {
        return col || color.accent;
    }

    property QtObject popups: QtObject {
        readonly property color background: typeof Theme !== "undefined" ? Theme.popupSurface : "#1f181d"
        readonly property color text: typeof Theme !== "undefined" ? Theme.colOnSurface : "#ffffff"
        readonly property color border: typeof Theme !== "undefined" ? Theme.popupBorder : "#412f3b"
    }

    property QtObject bar: QtObject {
        readonly property color background: typeof Theme !== "undefined" ? Theme.barBackground : "#130f12"
        readonly property color foreground: typeof Theme !== "undefined" ? Theme.colOnSurface : "#ffffff"
        readonly property color border: typeof Theme !== "undefined" ? Theme.barBorder : "#25252a"
    }

    property QtObject tooltip: QtObject {
        readonly property color background: typeof Theme !== "undefined" ? Theme.popupSurface : "#1f181d"
        readonly property color text: typeof Theme !== "undefined" ? Theme.colOnSurface : "#ffffff"
        readonly property color border: typeof Theme !== "undefined" ? Theme.popupBorder : "#412f3b"
    }
}
