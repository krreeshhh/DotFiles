// Cloudflare DNS state management
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool active: false
    property bool isPending: false

    function toggle() {
        if (root.isPending || dnsProcess.running) return;
        root.isPending = true;

        // Optimistic UI update
        root.active = !root.active;

        dnsProcess.command = ["/home/Krish/.local/bin/cloudflare-dns", root.active ? "on" : "off"];
        dnsProcess.running = true;
    }

    property Process dnsProcess: Process {
        id: dnsProcess
        onExited: (exitCode) => {
            root.isPending = false;
            checkProc.running = true;
        }
    }

    property Process checkProc: Process {
        id: checkProc
        command: ["/home/Krish/.local/bin/cloudflare-dns", "status"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.isPending) {
                    root.active = (data.trim() === "on");
                }
            }
        }
        onExited: (exitCode) => {
            if (!root.isPending) {
                root.active = (exitCode === 0);
            }
        }
    }

    property Timer pollTimer: Timer {
        id: pollTimer
        interval: 3000
        running: !root.isPending
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running && !root.isPending) {
                checkProc.running = true;
            }
        }
    }
}
