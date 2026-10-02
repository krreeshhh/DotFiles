import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import ".."

PanelWindow {
    id: root
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    signal openWifi()
    signal openBluetooth()

    property int currentBrightness: 100
    property int currentVolume: 100

    Process {
        id: brightProc
        command: ["brightnessctl", "get"]
        stdout: SplitParser {
            onRead: (line) => {
                var val = parseInt(line.trim());
                if (!isNaN(val)) root.currentBrightness = val;
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: (line) => {
                var match = line.trim().match(/([0-9]+\.[0-9]+|[0-9]+)/);
                if (match) {
                    root.currentVolume = Math.min(100, Math.round(parseFloat(match[1]) * 100));
                }
            }
        }
    }

    property bool shown: false

    onVisibleChanged: {
        if (visible) {
            bgCard.forceActiveFocus();
            brightProc.running = true;
            volProc.running = true;
        }
    }

    function openMenu() {
        closeTimer.stop();
        root.visible = true;
        root.shown = true;
        bgCard.forceActiveFocus();
        brightProc.running = true;
        volProc.running = true;
    }

    function closeMenu() {
        if (!root.shown) return;
        root.shown = false;
        closeTimer.restart();
    }

    function closeImmediate() {
        closeTimer.stop();
        root.shown = false;
        root.visible = false;
    }

    function toggle() {
        if (root.shown && root.visible) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!root.shown) {
                root.visible = false;
            }
        }
    }

    // Full screen background dismisser (click anywhere outside the card)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        enabled: root.shown
        onClicked: root.closeMenu()
    }

    Rectangle {
        id: bgCard
        width: 380
        height: contentColumn.implicitHeight + 32
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: 12
        radius: 16
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1
        focus: true
        transformOrigin: Item.TopRight

        opacity: root.shown ? 1.0 : 0.0
        transform: [
            Translate {
                id: cardTrans
                y: root.shown ? 0 : -28
                Behavior on y {
                    NumberAnimation {
                        duration: root.shown ? 240 : 160
                        easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
                    }
                }
            }
        ]

        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 200 : 150
                easing.type: root.shown ? Easing.OutCubic : Easing.InQuad
            }
        }

        Keys.onEscapePressed: {
            root.closeMenu();
        }

        // Catch clicks on empty card area so they don't propagate to the full-screen dismisser
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // 1. Header: Profile + Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Theme.primaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: "󰄛"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Krish"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.colOnSurface
                    }
                    Text {
                        text: "Hyprland Desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.colOnSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                // Lock & Power buttons
                Row {
                    spacing: 8
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: lockMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                        border.color: Theme.popupBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.colOnSurface
                        }
                        MouseArea {
                            id: lockMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeImmediate();
                                Quickshell.execDetached(["bash", "-c", "loginctl lock-session || hyprctl dispatch dpms off"]);
                            }
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: powerMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                        border.color: Theme.popupBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰐥"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.colorError
                        }
                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeImmediate();
                                Quickshell.execDetached(["nwg-bar"]);
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
            }

            // 2. Quick Action Tiles (2x2 Grid)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                // Wi-Fi Tile
                Rectangle {
                    Layout.fillWidth: true
                    height: 54
                    radius: 12
                    color: wifiTileMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                    border.color: wifiTileMouse.containsMouse ? Theme.primary : Theme.popupBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Text {
                            text: "󰤨"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            color: Theme.primary
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Wi-Fi"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.colOnSurface
                            }
                            Text {
                                text: "Networks"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "󰅂"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.colOnSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: wifiTileMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeImmediate();
                            root.openWifi();
                        }
                    }
                }

                // Bluetooth Tile
                Rectangle {
                    Layout.fillWidth: true
                    height: 54
                    radius: 12
                    color: btTileMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                    border.color: btTileMouse.containsMouse ? Theme.primary : Theme.popupBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Text {
                            text: "󰂯"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            color: Theme.primary
                        }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Bluetooth"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.colOnSurface
                            }
                            Text {
                                text: "Devices"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "󰅂"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.colOnSurfaceVariant
                        }
                    }
                    MouseArea {
                        id: btTileMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeImmediate();
                            root.openBluetooth();
                        }
                    }
                }
            }

            // 3. Volume & Brightness Sliders
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Volume Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰕾"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: Theme.primary
                    }

                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.currentVolume
                        onMoved: {
                            Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", Math.round(volSlider.value) + "%"]);
                            root.currentVolume = Math.round(volSlider.value);
                        }
                    }
                }

                // Brightness Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰃠"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: Theme.primary
                    }

                    Slider {
                        id: brightSlider
                        Layout.fillWidth: true
                        from: 5
                        to: 100
                        value: root.currentBrightness
                        onMoved: {
                            Quickshell.execDetached(["brightnessctl", "set", Math.round(brightSlider.value) + "%"]);
                            root.currentBrightness = Math.round(brightSlider.value);
                        }
                    }
                }
            }
        }
    }
}
