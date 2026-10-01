import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../plugins/omarchy-ledge"

PanelWindow {
    id: root
    property var modelData: null
    screen: modelData
    property color foreground: Theme.colOnSurface
    property color accent: Theme.primary
    property string fontFamily: Theme.fontFamily
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 48
    exclusiveZone: 36
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    signal toggleQuickSettings()
    signal toggleWifi()
    signal toggleBluetooth()

    Item {
        id: rootContent
        anchors.fill: parent

        // 1. Main 36px Top Bar Background
        Rectangle {
            id: mainBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            color: Theme.barBackground
        }

        // 2. Bottom Border Line (between the two corner curves)
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 35
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            height: 1
            color: Theme.popupBorder
        }

        // 3. Left Outward Curved Corner Fillet
        Canvas {
            id: leftFillet
            width: 12
            height: 12
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 36

            Connections {
                target: Theme
                function onBarBackgroundChanged() { leftFillet.requestPaint(); }
                function onPopupBorderChanged() { leftFillet.requestPaint(); }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.barBackground;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(12, 0);
                ctx.arc(12, 12, 12, 1.5 * Math.PI, Math.PI, true);
                ctx.lineTo(0, 0);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = Theme.popupBorder;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(12, 12, 11.5, 1.5 * Math.PI, Math.PI, true);
                ctx.stroke();
            }
        }

        // 4. Right Outward Curved Corner Fillet
        Canvas {
            id: rightFillet
            width: 12
            height: 12
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 36

            Connections {
                target: Theme
                function onBarBackgroundChanged() { rightFillet.requestPaint(); }
                function onPopupBorderChanged() { rightFillet.requestPaint(); }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.barBackground;
                ctx.beginPath();
                ctx.moveTo(12, 0);
                ctx.lineTo(0, 0);
                ctx.arc(0, 12, 12, 1.5 * Math.PI, 2.0 * Math.PI, false);
                ctx.lineTo(12, 0);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = Theme.popupBorder;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(0, 12, 11.5, 1.5 * Math.PI, 2.0 * Math.PI, false);
                ctx.stroke();
            }
        }

        // 5. Left Modules (Workspaces + Chat / Clipse)
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            height: 36
            spacing: 10

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
            }

            ChatButton {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 6. Center Clock (Centered on screen)
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            height: 36
        }

        // 7. Right Modules (Ledge, Media, Tray Drawer, Status Badges)
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            height: 36
            spacing: 10

            LedgeWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            MiniPlayer {
                anchors.verticalCenter: parent.verticalCenter
            }

            TrayDrawer {
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusCluster {
                anchors.verticalCenter: parent.verticalCenter
                onOpenQuickSettings: root.toggleQuickSettings()
                onOpenWifi: root.toggleWifi()
                onOpenBluetooth: root.toggleBluetooth()
            }
        }
    }
}
