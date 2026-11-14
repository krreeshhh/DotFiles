// Lightweight Wi-Fi / connectivity status (nmcli polled).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool wifiEnabled: true
    property bool connected: false
    property string ssid: ""
    property int strength: 0
    property bool ethernet: false
    property bool scanning: false

    readonly property string materialSymbol: {
        if (ethernet) return "lan";
        if (!wifiEnabled) return "signal_wifi_off";
        if (!connected) return "wifi_find";
        if (strength > 83) return "signal_wifi_4_bar";
        if (strength > 67) return "network_wifi";
        if (strength > 50) return "network_wifi_3_bar";
        if (strength > 33) return "network_wifi_2_bar";
        if (strength > 17) return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    readonly property string networkName: connected ? ssid : "Disconnected"

    function refresh() {
        statusProc.running = true;
    }

    function toggleWifi() {
        wifiEnabled = !wifiEnabled;
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "on" : "off"]);
    }

    function toggle() { toggleWifi(); }

    function rescan() {
        scanning = true;
        Quickshell.execDetached(["nmcli", "dev", "wifi", "list", "--rescan", "yes"]);
        scanTimer.restart();
    }

    function rescanWifi() { rescan(); }
    function enableWifi(v) {
        if (wifiEnabled !== v) toggleWifi();
    }

    Process {
        id: statusProc
        command: ["bash", "-c",
            "radio=$(nmcli radio wifi 2>/dev/null); " +
            "eth=$(nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -c '^ethernet:connected'); " +
            "wifi=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2\"|\"$3; exit}'); " +
            "printf '%s\\n%s\\n%s\\n' \"$radio\" \"$eth\" \"$wifi\""]
        stdout: SplitParser {
            property int lineIndex: 0
            onRead: (line) => {
                if (lineIndex === 0) {
                    root.wifiEnabled = line.trim() === "enabled";
                } else if (lineIndex === 1) {
                    root.ethernet = parseInt(line.trim()) > 0;
                } else if (lineIndex === 2) {
                    const [name, sig] = line.trim().split("|");
                    root.connected = !!name;
                    root.ssid = name ?? "";
                    root.strength = parseInt(sig) || 0;
                    lineIndex = -1;
                }
                lineIndex++;
            }
        }
        onRunningChanged: if (!running) stdout.lineIndex = 0
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: scanTimer
        interval: 2500
        repeat: false
        onTriggered: root.scanning = false
    }
}
