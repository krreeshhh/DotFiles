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
    name: Translation.tr("Power Profile")

    property string profileState: "ac"
    property bool isPending: false

    toggled: profileState === "battery"
    icon: (profileState === "battery") ? "energy_savings_leaf" : "local_fire_department"
    statusText: (profileState === "battery") ? Translation.tr("Battery Saver") : Translation.tr("Performance")
    tooltipText: (profileState === "battery")
        ? Translation.tr("Battery Saver: CPU 3.1GHz cap, GPU 1200MHz lock, 60Hz")
        : Translation.tr("AC Performance: CPU 4.5GHz Boost, Full GPU, 144Hz")

    mainAction: () => {
        if (root.isPending || runProc.running) return;
        root.isPending = true;

        // Optimistic UI update
        root.profileState = (root.profileState === "battery") ? "ac" : "battery";

        runProc.command = ["sudo", "/usr/local/bin/power-profile-manager", root.profileState];
        runProc.running = true;
    }

    altAction: () => {
        if (root.isPending || runProc.running) return;
        root.isPending = true;
        runProc.command = ["sudo", "/usr/local/bin/power-profile-manager", "auto"];
        runProc.running = true;
    }

    Process {
        id: runProc
        onExited: (exitCode) => {
            root.isPending = false;
            readStateProc.running = true;
        }
    }

    Process {
        id: readStateProc
        running: true
        command: ["cat", "/run/power-profile-state"]
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim();
                if (!root.isPending && (s === "battery" || s === "ac")) {
                    root.profileState = s;
                }
            }
        }
    }

    Timer {
        id: checkTimer
        interval: 2000
        running: !root.isPending
        repeat: true
        onTriggered: {
            if (!readStateProc.running && !root.isPending) {
                readStateProc.running = true;
            }
        }
    }
}
