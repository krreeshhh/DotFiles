// Cloudflare DNS state management
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool active: false

    function toggle() {
        Quickshell.execDetached(["/home/Krish/.local/bin/cloudflare-dns", "toggle"]);
        pollTimer.restart();
    }

    property Process checkProc: Process {
        id: checkProc
        command: ["/home/Krish/.local/bin/cloudflare-dns", "status"]
        stdout: SplitParser {
            onRead: data => {
                root.active = (data.trim() === "on");
            }
        }
        onExited: (exitCode) => {
            root.active = (exitCode === 0);
        }
    }

    property Timer pollTimer: Timer {
        id: pollTimer
        interval: 2000
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
