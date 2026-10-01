import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Commons"

Item {
    id: panel
    property string moduleName: ""
    property string ipcTarget: ""
    property bool manageIpc: true
    property var bar: null
    property bool opened: false
    property color barForeground: Color.foreground
    property color barBackground: Color.bar.background

    function open() { opened = true }
    function close() { opened = false }
    function toggle() { opened = !opened }
    function setting(key, fallback) { return fallback; }
}
