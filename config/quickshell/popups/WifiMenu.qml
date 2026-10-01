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
    property bool wifiEnabled: true
    property string activeSsid: ""
    property string expandedSsid: ""
    property string passwordInput: ""
    property string errorMessage: ""
    property string errorSsid: ""
    property string connectingSsid: ""
    property bool showPassword: false
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
        root.errorMessage = "";
        root.errorSsid = "";
        root.connectingSsid = "";
        bgCard.forceActiveFocus();
        radioProc.running = true;
        scanWifi(true, false);
    }

    function closeMenu() {
        if (!root.shown) return;
        root.shown = false;
        root.expandedSsid = "";
        root.passwordInput = "";
        root.errorMessage = "";
        root.errorSsid = "";
        root.showPassword = false;
        closeTimer.restart();
    }

    function closeImmediate() {
        closeTimer.stop();
        root.shown = false;
        root.visible = false;
        root.expandedSsid = "";
        root.passwordInput = "";
        root.errorMessage = "";
        root.errorSsid = "";
        root.showPassword = false;
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
        id: wifiModel
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: (line) => {
                root.wifiEnabled = (line.trim() === "enabled");
            }
        }
    }

    function updateWifiList(data) {
        if (!data || !Array.isArray(data)) return;

        var foundActive = "";
        for (var i = 0; i < data.length; i++) {
            if (data[i].inUse) {
                foundActive = data[i].ssid;
                break;
            }
        }
        root.activeSsid = foundActive;

        wifiModel.clear();
        for (var j = 0; j < data.length; j++) {
            var item = data[j];
            var isPending = (root.connectingSsid === item.ssid);
            wifiModel.append({
                ssid: item.ssid,
                signal: item.signal,
                security: item.security,
                inUse: item.inUse,
                isSaved: item.isSaved,
                isPending: isPending
            });
        }
    }

    Process {
        id: scanProc
        command: ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "list"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;
                try {
                    var data = JSON.parse(line);
                    root.updateWifiList(data);
                } catch (e) {
                    console.error("Failed to parse wifi list JSON:", e);
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.isScanning = false;
            }
        }
    }

    Process {
        id: connectProc
        property string targetSsid: ""
        property int targetIndex: -1
        command: []
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;
                try {
                    var res = JSON.parse(line);
                    if (res.success) {
                        root.errorMessage = "";
                        root.errorSsid = "";
                        root.expandedSsid = "";
                        root.passwordInput = "";
                        root.connectingSsid = "";
                        root.scanWifi(false, false);
                    } else {
                        root.errorMessage = res.error || "Connection failed";
                        root.errorSsid = connectProc.targetSsid;
                        root.connectingSsid = "";
                        if (connectProc.targetIndex >= 0 && connectProc.targetIndex < wifiModel.count) {
                            wifiModel.setProperty(connectProc.targetIndex, "isPending", false);
                        }
                        Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Quickshell Wi-Fi", "Wi-Fi Connection Failed", root.errorMessage]);
                    }
                } catch (e) {
                    console.error("Connect result parse error:", e);
                    root.connectingSsid = "";
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.connectingSsid = "";
                syncTimer1.restart();
                syncTimer2.restart();
            }
        }
    }

    Process {
        id: disconnectProc
        command: []
        onRunningChanged: {
            if (!running) {
                root.scanWifi(false, false);
            }
        }
    }

    Process {
        id: forgetProc
        command: []
        onRunningChanged: {
            if (!running) {
                root.scanWifi(false, false);
            }
        }
    }

    function toggleWifiRadio() {
        var newState = !root.wifiEnabled;
        root.wifiEnabled = newState;
        if (!newState) {
            root.isScanning = false;
            wifiModel.clear();
            root.activeSsid = "";
        }
        Quickshell.execDetached(["nmcli", "radio", "wifi", newState ? "on" : "off"]);
        if (newState) {
            syncTimer1.restart();
            syncTimer2.restart();
        }
    }

    function scanWifi(showSpinner, forceHardwareRescan) {
        if (showSpinner) root.isScanning = true;
        radioProc.running = true;
        if (forceHardwareRescan) {
            scanProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "list", "--rescan"];
        } else {
            scanProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "list"];
        }
        scanProc.running = true;
    }

    function connectToNetwork(index, ssid, password) {
        root.errorMessage = "";
        root.errorSsid = "";
        root.connectingSsid = ssid;
        if (index >= 0 && index < wifiModel.count) {
            wifiModel.setProperty(index, "isPending", true);
        }
        connectProc.targetSsid = ssid;
        connectProc.targetIndex = index;

        if (password && password.length > 0) {
            connectProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "connect", ssid, password];
        } else {
            connectProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "connect", ssid];
        }
        connectProc.running = true;
    }

    function disconnectNetwork(index, ssid) {
        if (index >= 0 && index < wifiModel.count) {
            wifiModel.setProperty(index, "isPending", true);
            wifiModel.setProperty(index, "inUse", false);
        }
        disconnectProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "disconnect", ssid];
        disconnectProc.running = true;
        syncTimer1.restart();
        syncTimer2.restart();
    }

    function forgetNetwork(index, ssid) {
        root.errorMessage = "";
        root.errorSsid = "";
        if (root.expandedSsid === ssid) {
            root.expandedSsid = "";
        }
        forgetProc.command = ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "forget", ssid];
        forgetProc.running = true;
        if (index >= 0 && index < wifiModel.count) {
            wifiModel.setProperty(index, "isSaved", false);
        }
        Quickshell.execDetached(["notify-send", "-a", "Quickshell Wi-Fi", "Network Forgotten", "Removed saved credentials for " + ssid]);
    }

    Timer {
        id: syncTimer1
        interval: 1000
        repeat: false
        onTriggered: root.scanWifi(false, false)
    }

    Timer {
        id: syncTimer2
        interval: 2200
        repeat: false
        onTriggered: root.scanWifi(false, false)
    }

    Timer {
        id: syncTimer3
        interval: 3800
        repeat: false
        onTriggered: root.scanWifi(false, false)
    }

    Timer {
        id: livePoller
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!root.isScanning && !scanProc.running && !connectProc.running && root.expandedSsid === "") {
                root.scanWifi(false, false);
            }
        }
    }

    function getWifiIcon(signalVal) {
        if (signalVal >= 75) return "󰤨";
        if (signalVal >= 50) return "󰤥";
        if (signalVal >= 25) return "󰤢";
        if (signalVal > 0) return "󰤟";
        return "󰤯";
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
        height: 460
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
                        text: "󰤨"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: "Wi-Fi Networks"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.colOnSurface
                    }
                    Text {
                        text: root.wifiEnabled ? (wifiModel.count + " available") : "Radio off"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.colOnSurfaceVariant
                    }
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
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: root.isScanning ? Theme.primary : Theme.colOnSurface
                        rotation: root.isScanning ? 360 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: 800; loops: Animation.Infinite }
                        }
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanWifi(true, true)
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

            // Global Error Banner (shown if error is general or unconnected)
            Rectangle {
                visible: root.errorMessage.length > 0 && root.errorSsid.length === 0
                Layout.fillWidth: true
                height: 32
                radius: 8
                color: Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.15)
                border.color: Theme.colorError
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰅚"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.colorError
                    }

                    Text {
                        text: root.errorMessage
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.colorError
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // 2. Wi-Fi Switch Toggle Row
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 12
                color: wifiToggleMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                border.color: root.wifiEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Theme.popupBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: wifiToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWifiRadio()
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
                        color: root.wifiEnabled ? Theme.primaryContainer : Qt.rgba(1, 1, 1, 0.06)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.wifiEnabled ? "󰤨" : "󰤮"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: root.wifiEnabled ? Theme.primary : Theme.colOnSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: root.wifiEnabled ? "Wi-Fi Enabled" : "Wi-Fi Disabled"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.wifiEnabled ? Theme.colOnSurface : Theme.colOnSurfaceVariant
                        }
                        Text {
                            text: root.wifiEnabled ? (root.activeSsid ? root.activeSsid : "Available") : "Click to turn on"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: root.wifiEnabled && root.activeSsid ? Theme.primary : Theme.colOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.preferredWidth: 170
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Material You Pill Switch
                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.wifiEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)
                        border.color: root.wifiEnabled ? Theme.primary : Theme.popupBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            y: 2
                            x: root.wifiEnabled ? 23 : 3
                            color: root.wifiEnabled ? Theme.colOnPrimary : Theme.colOnSurfaceVariant

                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }

            // 3. Network List
            ListView {
                id: wifiListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: wifiModel

                // Empty / Disabled State Placeholder
                Item {
                    anchors.fill: parent
                    visible: wifiModel.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            id: emptyWifiIcon
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isScanning ? "󰑐" : (!root.wifiEnabled ? "󰤮" : "󰤯")
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            color: root.isScanning ? Theme.primary : Theme.colOnSurfaceVariant

                            RotationAnimation {
                                target: emptyWifiIcon
                                running: root.isScanning
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: !root.wifiEnabled
                                ? "Wi-Fi is turned off"
                                : (root.isScanning ? "Scanning for networks…" : "No networks found")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.colOnSurfaceVariant
                        }
                    }
                }

                delegate: Rectangle {
                    id: netItem
                    width: wifiListView.width
                    property bool isExpanded: (root.expandedSsid === model.ssid && !model.inUse)
                    property bool hasError: (root.errorSsid === model.ssid && root.errorMessage.length > 0)
                    height: isExpanded ? (hasError ? 128 : 96) : 52
                    radius: 10
                    color: model.inUse ? Theme.popupSurfaceSelected : (itemMouse.containsMouse ? Theme.popupSurfaceVariant : Qt.rgba(1, 1, 1, 0.05))
                    border.color: model.inUse ? Theme.primary : (hasError ? Theme.colorError : Theme.popupBorder)
                    border.width: (model.inUse || hasError) ? 1.5 : 1

                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (model.inUse) return;
                            root.errorMessage = "";
                            root.errorSsid = "";
                            if (model.isSaved) {
                                // Saved network: connect immediately without asking password!
                                root.connectToNetwork(index, model.ssid, "");
                            } else if (model.security.length > 0) {
                                // Unsaved secured network: toggle password box
                                root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid;
                            } else {
                                // Open network: connect directly
                                root.connectToNetwork(index, model.ssid, "");
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: root.getWifiIcon(model.signal)
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                color: model.inUse ? Theme.primary : Theme.colOnSurface
                            }

                            ColumnLayout {
                                spacing: 1
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: model.ssid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: model.inUse || model.isSaved
                                        color: model.inUse ? Theme.primary : Theme.colOnSurface
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 140
                                    }

                                    // Saved badge
                                    Rectangle {
                                        visible: model.isSaved && !model.inUse
                                        width: 44
                                        height: 16
                                        radius: 4
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "SAVED"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: Theme.primary
                                        }
                                    }
                                }

                                Text {
                                    text: {
                                        if (model.isPending) return (model.inUse ? "Disconnecting…" : "Connecting…");
                                        if (model.inUse) return "Connected";
                                        if (model.isSaved) return (model.security ? model.security : "Open");
                                        return (model.security ? model.security : "Open");
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: model.inUse ? Theme.primary : Theme.colOnSurfaceVariant
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Forget Network Button (for saved networks that are not active)
                            Rectangle {
                                visible: model.isSaved && !model.inUse
                                width: 28
                                height: 28
                                radius: 6
                                color: forgetMouse.containsMouse ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.2) : Theme.popupSurfaceVariant
                                border.color: forgetMouse.containsMouse ? Theme.colorError : Theme.popupBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: forgetMouse.containsMouse ? Theme.colorError : Theme.colOnSurfaceVariant
                                }

                                MouseArea {
                                    id: forgetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.forgetNetwork(index, model.ssid);
                                    }
                                }
                            }

                            // Main Action Button (Connect / Disconnect)
                            Rectangle {
                                id: actionBtn
                                width: 84
                                height: 30
                                radius: 8
                                color: model.inUse
                                    ? (btnMouse.containsMouse ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.22) : Theme.popupSurfaceVariant)
                                    : (btnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
                                border.color: model.inUse
                                    ? (btnMouse.containsMouse ? Theme.colorError : Theme.popupBorder)
                                    : (btnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary)
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.isPending
                                        ? (model.inUse ? "Disconnecting…" : "Connecting…")
                                        : (model.inUse ? "Disconnect" : "Connect")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: model.inUse ? Theme.colorError : Theme.colOnPrimary
                                }

                                MouseArea {
                                    id: btnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (model.inUse) {
                                            root.disconnectNetwork(index, model.ssid);
                                        } else {
                                            root.errorMessage = "";
                                            root.errorSsid = "";
                                            if (model.isSaved) {
                                                // Saved network: connect directly without password!
                                                root.connectToNetwork(index, model.ssid, "");
                                            } else if (model.security.length > 0) {
                                                root.expandedSsid = (root.expandedSsid === model.ssid) ? "" : model.ssid;
                                            } else {
                                                root.connectToNetwork(index, model.ssid, "");
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Inline Error Banner inside expanded card
                        Rectangle {
                            visible: netItem.isExpanded && netItem.hasError
                            Layout.fillWidth: true
                            height: 24
                            radius: 6
                            color: Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.16)
                            border.color: Theme.colorError
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: "󰅚"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.colorError
                                }

                                Text {
                                    text: root.errorMessage
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.colorError
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Password input row if expanded
                        RowLayout {
                            visible: netItem.isExpanded
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 6
                                color: Theme.popupSurfaceVariant
                                border.color: netItem.hasError ? Theme.colorError : Theme.popupBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 6
                                    spacing: 4

                                    TextField {
                                        id: passField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholderText: "Enter Password..."
                                        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.colOnSurface
                                        background: Item {}
                                        onTextChanged: {
                                            root.passwordInput = text;
                                            if (root.errorSsid === model.ssid) {
                                                root.errorMessage = "";
                                                root.errorSsid = "";
                                            }
                                        }
                                        onAccepted: {
                                            root.connectToNetwork(index, model.ssid, passField.text);
                                        }
                                    }

                                    // Reveal / Hide password button
                                    Text {
                                        text: root.showPassword ? "󰈈" : "󰈉"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        color: eyeMouse.containsMouse ? Theme.primary : Theme.colOnSurfaceVariant

                                        MouseArea {
                                            id: eyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.showPassword = !root.showPassword
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 68
                                height: 32
                                radius: 6
                                color: joinBtnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                                border.color: joinBtnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.isPending ? "..." : "Join"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.colOnPrimary
                                }

                                MouseArea {
                                    id: joinBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.connectToNetwork(index, model.ssid, passField.text);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
