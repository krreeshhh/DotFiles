import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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

    property bool isScanning: false
    property bool btEnabled: true
    property var currentScanMacs: []

    property bool shown: false

    onVisibleChanged: {
        if (visible) {
            bgCard.forceActiveFocus();
        }
    }

    function openMenu() {
        closeTimer.stop();
        root.visible = true;
        root.shown = true;
        bgCard.forceActiveFocus();
        scanDevices(true);
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

    ListModel {
        id: btModel
    }

    Process {
        id: powerProc
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
        stdout: SplitParser {
            onRead: (line) => {
                root.btEnabled = (line.trim() === "on");
            }
        }
    }

    Process {
        id: discoveryProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (line.indexOf("Device ") !== -1 || line.indexOf("Discovery started") !== -1) {
                    if (!btProc.running) {
                        btProc.running = true;
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.isScanning = false;
                btProc.running = true;
            }
        }
    }

    Process {
        id: btProc
        command: ["bash", "-c", "bluetoothctl devices | while read -r _ mac name; do info=$(bluetoothctl info \"$mac\" 2>/dev/null); conn=$(echo \"$info\" | grep -q \"Connected: yes\" && echo \"true\" || echo \"false\"); bat=$(echo \"$info\" | grep \"Battery Percentage:\" | sed -n 's/.*(\\([0-9]*\\)).*/\\1/p'); echo \"$mac|$conn|$bat|$name\"; done"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;
                var parts = line.split("|");
                if (parts.length >= 4) {
                    var mac = parts[0];
                    var conn = (parts[1] === "true");
                    var bat = parts[2] ? parts[2] : "";
                    var name = parts[3];
                    if (!name || name.length === 0) return;

                    if (root.currentScanMacs.indexOf(mac) === -1) {
                        root.currentScanMacs.push(mac);
                    }

                    var found = false;
                    for (var i = 0; i < btModel.count; i++) {
                        if (btModel.get(i).mac === mac) {
                            found = true;
                            btModel.setProperty(i, "connected", conn);
                            btModel.setProperty(i, "name", name);
                            btModel.setProperty(i, "battery", bat);
                            btModel.setProperty(i, "isPending", false);
                            break;
                        }
                    }
                    if (!found) {
                        btModel.append({
                            mac: mac,
                            name: name,
                            connected: conn,
                            battery: bat,
                            isPending: false
                        });
                    }
                }
            }
        }
        onRunningChanged: {
            if (running) {
                root.currentScanMacs = [];
            } else {
                if (!discoveryProc.running) {
                    root.isScanning = false;
                }
            }
        }
    }

    function toggleBluetoothRadio() {
        var newState = !root.btEnabled;
        root.btEnabled = newState;
        if (!newState) {
            root.isScanning = false;
        }
        Quickshell.execDetached(["bluetoothctl", "power", newState ? "on" : "off"]);
        if (newState) {
            syncTimer1.restart();
            syncTimer2.restart();
        }
    }

    function scanDevices(showSpinner) {
        powerProc.running = true;
        if (!root.btEnabled) {
            root.btEnabled = true;
            Quickshell.execDetached(["bluetoothctl", "power", "on"]);
        }

        btProc.running = true;

        if (showSpinner) {
            root.isScanning = true;
            if (discoveryProc.running) {
                btProc.running = true;
            } else {
                discoveryProc.running = true;
            }
        }
    }

    function toggleDevice(index, mac, currentlyConnected) {
        btModel.setProperty(index, "isPending", true);
        if (currentlyConnected) {
            btModel.setProperty(index, "connected", false);
            Quickshell.execDetached(["bluetoothctl", "disconnect", mac]);
        } else {
            btModel.setProperty(index, "connected", true);
            Quickshell.execDetached(["bash", "-c", "bluetoothctl pair " + mac + " 2>/dev/null; bluetoothctl trust " + mac + " 2>/dev/null; bluetoothctl connect " + mac]);
        }
        syncTimer1.restart();
        syncTimer2.restart();
        syncTimer3.restart();
    }

    Timer {
        id: syncTimer1
        interval: 1000
        repeat: false
        onTriggered: root.scanDevices(false)
    }

    Timer {
        id: syncTimer2
        interval: 2200
        repeat: false
        onTriggered: root.scanDevices(false)
    }

    Timer {
        id: syncTimer3
        interval: 3800
        repeat: false
        onTriggered: root.scanDevices(false)
    }

    Timer {
        id: livePoller
        interval: 2500
        running: root.visible
        repeat: true
        onTriggered: {
            if (!btProc.running) {
                root.scanDevices(false);
            }
        }
    }

    function getDeviceIcon(name) {
        var n = name.toLowerCase();
        if (n.indexOf("bud") !== -1 || n.indexOf("ear") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("headset") !== -1 || n.indexOf("audio") !== -1) return "󰋋";
        if (n.indexOf("mouse") !== -1 || n.indexOf("trackpad") !== -1) return "󰍽";
        if (n.indexOf("keyboard") !== -1) return "󰌌";
        if (n.indexOf("phone") !== -1 || n.indexOf("iphone") !== -1 || n.indexOf("android") !== -1) return "";
        if (n.indexOf("watch") !== -1 || n.indexOf("band") !== -1) return "󰥔";
        return "󰂯";
    }

    // Full screen background dismisser (click anywhere outside the card)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        enabled: root.shown
        onClicked: root.closeMenu()
    }

    // Card UI
    Rectangle {
        id: bgCard
        width: 360
        height: 420
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

        // Catch clicks on empty card area
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // 1. Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: Theme.primaryContainer

                    Text {
                        anchors.centerIn: parent
                        text: "󰂯"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: Theme.primary
                    }
                }

                Text {
                    text: "Bluetooth Devices"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.colOnSurface
                }

                Item { Layout.fillWidth: true }

                // Rescan Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: rescanMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                    border.color: Theme.popupBorder
                    border.width: 1

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: root.isScanning ? Theme.primary : Theme.colOnSurface

                        RotationAnimation {
                            target: scanIcon
                            running: root.isScanning
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanDevices(true)
                    }
                }

                // Close Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: closeMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                    border.color: Theme.popupBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: closeMouse.containsMouse ? Theme.colorError : Theme.colOnSurface
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeMenu()
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.popupBorder
            }

            // 2. Bluetooth Switch Toggle Row
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 12
                color: btToggleMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                border.color: root.btEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Theme.popupBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: btToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleBluetoothRadio()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: root.btEnabled ? Theme.primaryContainer : Qt.rgba(1, 1, 1, 0.06)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.btEnabled ? "󰂯" : "󰂲"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: root.btEnabled ? Theme.primary : Theme.colOnSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: root.btEnabled ? "Bluetooth Enabled" : "Bluetooth Disabled"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.btEnabled ? Theme.colOnSurface : Theme.colOnSurfaceVariant
                        }
                        Text {
                            text: root.btEnabled ? (root.isScanning ? "Discovering devices…" : "Ready") : "Click to turn on"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: root.btEnabled && root.isScanning ? Theme.primary : Theme.colOnSurfaceVariant
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Material You Pill Switch
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.btEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)
                        border.color: root.btEnabled ? Theme.primary : Theme.popupBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            y: 2
                            x: root.btEnabled ? 23 : 3
                            color: root.btEnabled ? Theme.colOnPrimary : Theme.colOnSurfaceVariant

                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

            // 3. Device List
            ListView {
                id: btListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: btModel

                // Empty / Scanning State
                Item {
                    anchors.fill: parent
                    visible: btModel.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            id: emptyScanIcon
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isScanning ? "󰑐" : (!root.btEnabled ? "󰂲" : "󰂯")
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            color: root.isScanning ? Theme.primary : Theme.colOnSurfaceVariant

                            RotationAnimation {
                                target: emptyScanIcon
                                running: root.isScanning
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: !root.btEnabled
                                ? "Bluetooth is disabled"
                                : (root.isScanning ? "Scanning for nearby devices…" : "No devices found")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colOnSurfaceVariant
                        }
                    }
                }

                delegate: Rectangle {
                    id: devItem
                    width: btListView.width
                    height: 52
                    radius: 10
                    color: model.connected ? Theme.popupSurfaceSelected : (rowMouse.containsMouse ? Theme.popupSurfaceVariant : Qt.rgba(1, 1, 1, 0.05))
                    border.color: model.connected ? Theme.primary : Theme.popupBorder
                    border.width: 1

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.toggleDevice(index, model.mac, model.connected);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: root.getDeviceIcon(model.name)
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            color: model.connected ? Theme.primary : Theme.colOnSurface
                        }

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: model.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: model.connected
                                color: model.connected ? Theme.primary : Theme.colOnSurface
                                elide: Text.ElideRight
                                Layout.preferredWidth: 150
                            }
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: model.isPending ? (model.connected ? "Connecting..." : "Disconnecting...") : (model.connected ? "Connected" : "Disconnected")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: model.connected ? Theme.primary : Theme.colOnSurfaceVariant
                                }
                                Text {
                                    visible: model.connected && model.battery && model.battery.length > 0
                                    text: "• 󰥉 " + model.battery + "%"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.colOnSurfaceVariant
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: actionBtn
                            width: 88
                            height: 30
                            radius: 8
                            color: model.connected
                                ? (btnMouse.containsMouse ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.22) : Theme.popupSurfaceVariant)
                                : (btnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
                            border.color: model.connected
                                ? (btnMouse.containsMouse ? Theme.colorError : Theme.popupBorder)
                                : (btnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary)
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.isPending ? (model.connected ? "Connecting…" : "Disconnecting…") : (model.connected ? "Disconnect" : "Connect")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: model.connected ? Theme.colorError : Theme.colOnPrimary
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.toggleDevice(index, model.mac, model.connected);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
