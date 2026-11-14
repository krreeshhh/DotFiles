import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"
import "../lib"

Item {
    id: root
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool hasWindow: activeWindow !== null && activeWindow.title !== ""

    implicitWidth: colLayout.implicitWidth
    implicitHeight: Theme.sizes.barHeight

    ColumnLayout {
        id: colLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Theme.font.pixelSize.smaller
            color: Theme.colSubtext
            elide: Text.ElideRight
            text: root.hasWindow ? (root.activeWindow?.appId ?? "") : "Desktop"
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Theme.font.pixelSize.small
            color: Theme.colOnLayer0
            elide: Text.ElideRight
            text: root.hasWindow ? (root.activeWindow?.title ?? "") : "Hyprland"
        }
    }
}
