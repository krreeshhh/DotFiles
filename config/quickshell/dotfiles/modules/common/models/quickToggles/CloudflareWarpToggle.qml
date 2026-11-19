import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    name: Translation.tr("Cloudflare")

    toggled: false
    icon: "cloud_lock"
    statusText: toggled ? Translation.tr("1.1.1.1") : Translation.tr("Off")
    tooltipText: toggled 
        ? Translation.tr("Cloudflare DNS Active (1.1.1.1) - Click to restore original DNS") 
        : Translation.tr("Click to enable Cloudflare 1.1.1.1 DNS")

    mainAction: () => {
        Quickshell.execDetached(["/home/Krish/.local/bin/cloudflare-dns", "toggle"]);
        pollTimer.restart();
    }

    Process {
        id: checkDnsProc
        command: ["/home/Krish/.local/bin/cloudflare-dns", "status"]
        stdout: SplitParser {
            onRead: data => {
                root.toggled = (data.trim() === "on");
            }
        }
        onExited: (exitCode) => {
            root.toggled = (exitCode === 0);
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkDnsProc.running) {
                checkDnsProc.running = true;
            }
        }
    }
}
