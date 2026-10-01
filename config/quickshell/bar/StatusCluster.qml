import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."

Row {
    id: root
    spacing: 8
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    signal openQuickSettings()
    signal openWifi()
    signal openBluetooth()

    property int currentBrightness: 100
    property int currentVolume: 100
    property bool isMuted: false
    property string btState: "on"
    property string wifiState: "connected:100"
    property bool caffeineActive: false

    function getWifiIcon() {
        if (root.wifiState === "disabled") return "󰤮";
        if (root.wifiState === "disconnected") return "󰤯";
        if (root.wifiState.startsWith("connected:")) {
            var sig = parseInt(root.wifiState.substring(10)) || 100;
            if (sig >= 75) return "󰤨";
            if (sig >= 50) return "󰤥";
            if (sig >= 25) return "󰤢";
            return "󰤟";
        }
        return "󰤨";
    }

    Process {
        id: caffeineProc
        command: ["bash", "/home/Krish/.config/hypr/scripts/caffeine.sh", "status"]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim();
                root.caffeineActive = (s === "active");
            }
        }
    }

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
                line = line.trim();
                if (!line) return;
                root.isMuted = line.indexOf("[MUTED]") !== -1;
                var match = line.match(/([0-9]+\.[0-9]+|[0-9]+)/);
                if (match) {
                    var v = parseFloat(match[1]);
                    root.currentVolume = Math.round(v * 100);
                }
            }
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-c", "bluetoothctl devices Connected | grep -q Device && echo 'connected' || (bluetoothctl show | grep -q 'Powered: yes' && echo 'on' || echo 'off')"]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim();
                if (s) root.btState = s;
            }
        }
    }

    Process {
        id: wifiStatusProc
        command: ["python3", "/home/Krish/.config/quickshell/scripts/wifi.py", "status"]
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim();
                if (s) root.wifiState = s;
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            brightProc.running = true;
            volProc.running = true;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btStatusProc.running = true;
            wifiStatusProc.running = true;
            caffeineProc.running = true;
        }
    }

    // 1. Caffeine (Idle & Sleep Inhibitor)
    Item {
        width: 24
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: "󰅶"
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: root.caffeineActive 
                ? Theme.primary 
                : (caffeineMouse.containsMouse ? Theme.primary : Theme.colOnSurfaceVariant)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: caffeineMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["bash", "/home/Krish/.config/hypr/scripts/caffeine.sh", "toggle"]);
                root.caffeineActive = !root.caffeineActive;
                caffeineTimer.restart();
            }
        }

        Timer {
            id: caffeineTimer
            interval: 350
            onTriggered: caffeineProc.running = true
        }
    }

    // 2. Notification Center Indicator
    Item {
        width: 22
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: "󰂚"
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: notifMouse.containsMouse ? Theme.primary : Theme.colOnSurface
        }

        MouseArea {
            id: notifMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["dunstctl", "history-pop"])
        }
    }

    // 3. Bluetooth
    Item {
        width: 22
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: root.btState === "connected" ? "󰂱" : (root.btState === "off" ? "󰂲" : "󰂯")
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: btMouse.containsMouse ? Theme.primary : (root.btState === "connected" ? Theme.primary : (root.btState === "off" ? Theme.colOnSurfaceVariant : Theme.colOnSurface))
        }

        MouseArea {
            id: btMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openBluetooth()
        }
    }

    // 4. Network / Wi-Fi
    Item {
        width: 22
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.centerIn: parent
            text: root.getWifiIcon()
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: netMouse.containsMouse 
                ? Theme.primary 
                : (root.wifiState.startsWith("connected:") ? Theme.primary : (root.wifiState === "disabled" ? Theme.colOnSurfaceVariant : Theme.colOnSurface))
        }

        MouseArea {
            id: netMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openWifi()
        }
    }

    // 5. Audio / Volume
    Item {
        width: volRow.implicitWidth + 4
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: volRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: root.isMuted ? "󰝟" : (root.currentVolume > 50 ? "󰕾" : (root.currentVolume > 0 ? "󰖀" : "󰕿"))
                font.family: Theme.fontFamily
                font.pixelSize: 15
                color: volMouse.containsMouse ? Theme.primary : Theme.colOnSurface
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.currentVolume + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: volMouse.containsMouse ? Theme.primary : Theme.colOnSurface
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: volMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                    volProc.running = true;
                } else {
                    root.openQuickSettings();
                }
            }
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]);
                    root.currentVolume = Math.min(100, root.currentVolume + 5);
                    volProc.running = true;
                } else if (wheel.angleDelta.y < 0) {
                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]);
                    root.currentVolume = Math.max(0, root.currentVolume - 5);
                    volProc.running = true;
                }
            }
        }
    }

    // 6. Screen Backlight
    Item {
        id: brightItem
        width: brightRow.implicitWidth + 4
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: brightRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "󰃠"
                font.family: Theme.fontFamily
                font.pixelSize: 15
                color: brightMouse.containsMouse ? Theme.primary : Theme.colOnSurface
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.currentBrightness + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: brightMouse.containsMouse ? Theme.primary : Theme.colOnSurface
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: brightMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openQuickSettings()
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    Quickshell.execDetached(["brightnessctl", "set", "5%+"]);
                    root.currentBrightness = Math.min(100, root.currentBrightness + 5);
                    brightProc.running = true;
                } else if (wheel.angleDelta.y < 0) {
                    Quickshell.execDetached(["brightnessctl", "set", "5%-"]);
                    root.currentBrightness = Math.max(5, root.currentBrightness - 5);
                    brightProc.running = true;
                }
            }
        }
    }

    // 7. Battery
    Item {
        id: batItem
        width: batRow.implicitWidth + 4
        height: 36
        anchors.verticalCenter: parent.verticalCenter

        property var displayDevice: UPower.displayDevice
        property int percentage: displayDevice ? Math.round(displayDevice.percentage * 100) : 100
        property bool isCharging: displayDevice ? (displayDevice.state === UPowerDeviceState.Charging || displayDevice.state === UPowerDeviceState.FullyCharged) : true

        Row {
            id: batRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: batItem.isCharging ? "󰂄" : (batItem.percentage <= 20 ? "󰁺" : (batItem.percentage <= 50 ? "󰁽" : (batItem.percentage <= 80 ? "󰂀" : "󰁹")))
                font.family: Theme.fontFamily
                font.pixelSize: 15
                color: batMouse.containsMouse ? Theme.primary : (batItem.percentage <= 15 ? Theme.colorError : Theme.colOnSurface)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: batItem.percentage + "%"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: batMouse.containsMouse ? Theme.primary : (batItem.percentage <= 15 ? Theme.colorError : Theme.colOnSurface)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: batMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openQuickSettings()
        }
    }
}
