// Power profile state management.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string currentProfile: "ac"
    readonly property bool isBattery: currentProfile === "battery"

    function toggle() {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "toggle"]);
        pollTimer.restart();
    }

    function setBattery() {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "battery"]);
        pollTimer.restart();
    }

    function setAc() {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "ac"]);
        pollTimer.restart();
    }

    function setAuto() {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "auto"]);
        pollTimer.restart();
    }

    property Process checkProc: Process {
        id: checkProc
        command: ["cat", "/run/power-profile-state"]
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim();
                if (s === "battery" || s === "ac") {
                    root.currentProfile = s;
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        id: pollTimer
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running) {
                checkProc.running = true;
            }
        }
    }
}
