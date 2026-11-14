import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import ".."
import "../services"
import "../lib"

Scope {
    id: root

    function toggle() { GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen; }
    function open() { GlobalStates.sidebarRightOpen = true; }
    function close() { GlobalStates.sidebarRightOpen = false; }

    PanelWindow {
        id: panel

        visible: GlobalStates.sidebarRightOpen
        exclusiveZone: 0
        implicitWidth: Theme.sizes.sidebarWidth
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        BackgroundEffect.blurRegion: Region { item: card }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panel);
                Notifications.markAllRead();
            } else {
                GlobalFocusGrab.removeDismissable(panel);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Rectangle {
            id: card
            anchors {
                fill: parent
                topMargin: Theme.sizes.hyprlandGapsOut
                bottomMargin: Theme.sizes.hyprlandGapsOut
                rightMargin: Theme.sizes.hyprlandGapsOut
                leftMargin: Theme.sizes.elevationMargin
            }
            color: Theme.colLayer0
            radius: Theme.rounding.screen - Theme.sizes.hyprlandGapsOut + 1
            border.width: 1
            border.color: Theme.colLayer0Border

            SidebarRightContent {
                anchors.fill: parent
                anchors.margins: 10
            }
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }
    }

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
