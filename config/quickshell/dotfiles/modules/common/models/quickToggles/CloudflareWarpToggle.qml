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

    property bool isPending: false

    toggled: false
    icon: "cloud_lock"
    statusText: toggled ? Translation.tr("1.1.1.1") : Translation.tr("Off")
    tooltipText: toggled 
        ? Translation.tr("Cloudflare DNS Active (1.1.1.1) - Click to restore original DNS") 
        : Translation.tr("Click to enable Cloudflare 1.1.1.1 DNS")

    mainAction: () => {
        // Prevent rapid double-clicks while DNS switch is processing
        if (root.isPending || dnsProcess.running) return;

        root.isPending = true;

        // 1. Optimistic UI update: change UI state immediately before background execution
        root.toggled = !root.toggled;

        // 2. Execute DNS change in background; notification will fire upon completion
        dnsProcess.command = [(Quickshell.env ? Quickshell.env("HOME") : "") + "/.local/bin/cloudflare-dns", root.toggled ? "on" : "off"];
        dnsProcess.running = true;
    }

    Process {
        id: dnsProcess
        onExited: (exitCode, exitStatus) => {
            root.isPending = false;
            // Verify and confirm actual DNS state
            checkDnsProc.running = true;
        }
    }

    Process {
        id: checkDnsProc
        command: [(Quickshell.env ? Quickshell.env("HOME") : "") + "/.local/bin/cloudflare-dns", "status"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.isPending) {
                    root.toggled = (data.trim() === "on");
                }
            }
        }
        onExited: (exitCode) => {
            if (!root.isPending) {
                root.toggled = (exitCode === 0);
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        running: !root.isPending
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkDnsProc.running && !root.isPending) {
                checkDnsProc.running = true;
            }
        }
    }
}
