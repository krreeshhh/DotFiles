import QtQuick
import "../Commons"

Item {
    id: root

    property string moduleName: ""
    property int barSize: Style.bar.height
    property var settings: ({})
    property var screen: null

    property QtObject defaultBar: QtObject {
        property color foreground: Color.foreground
        property color background: Color.background
        property color accent: Color.accent
        property color muted: Color.muted
        property string fontFamily: Style.font.family
        property int barSize: Style.bar.height
        property int height: Style.bar.height
        function hideTooltip(item) {}
        function showTooltip(item, text) {}
    }

    property var bar: defaultBar

    implicitHeight: barSize
    implicitWidth: childrenRect.width

    function setting(name, defaultValue) {
        if (settings && settings[name] !== undefined) {
            return settings[name];
        }
        return defaultValue !== undefined ? defaultValue : "";
    }

    function screenSetting(name, defaultValue) {
        return setting(name, defaultValue);
    }
}
