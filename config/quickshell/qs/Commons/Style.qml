import QtQuick

pragma Singleton

QtObject {
    id: style

    readonly property int cornerRadius: 10
    readonly property int gapsOut: 8
    readonly property int gapsIn: 6
    readonly property int barSize: 36

    function space(px) {
        return Math.round(px);
    }

    function normalFillFor(fg, bg) {
        return Qt.rgba(bg.r, bg.g, bg.b, 0.15);
    }

    function accentFillFor(fg, bg) {
        return Qt.rgba(bg.r, bg.g, bg.b, 0.25);
    }

    property QtObject spacing: QtObject {
        readonly property int xxs: 2
        readonly property int xs: 4
        readonly property int sm: 6
        readonly property int md: 8
        readonly property int lg: 10
        readonly property int xl: 12
        readonly property int labelGap: 6
        readonly property int panelGap: 8
        readonly property int rowPaddingX: 8
        readonly property int popupPadding: 12
        readonly property int cardPadding: 12
        readonly property int controlPaddingX: 8
        readonly property int controlPaddingY: 4
        readonly property int controlHeight: 28
        readonly property int buttonPadding: 6
        readonly property int panelPadding: 10
    }

    property QtObject font: QtObject {
        readonly property string family: typeof Theme !== "undefined" ? Theme.fontFamily : "JetBrainsMono Nerd Font"
        readonly property int caption: 10
        readonly property int bodySmall: 11
        readonly property int body: 12
        readonly property int subtitle: 13
        readonly property int title: 15
        readonly property int heading: 16
        readonly property int display: 20
        readonly property int displayLarge: 24
        readonly property int icon: 14
        readonly property int iconSmall: 12
        readonly property int iconLarge: 18
    }

    property QtObject bar: QtObject {
        readonly property int height: 36
        readonly property int iconSlot: 26
        readonly property int iconCanvas: 26
        readonly property int iconFont: 11
    }
}
