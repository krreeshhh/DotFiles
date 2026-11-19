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

    toggled: profileState === "battery"
    icon: (profileState === "battery") ? "energy_savings_leaf" : "local_fire_department"
    statusText: (profileState === "battery") ? Translation.tr("Battery Saver") : Translation.tr("Performance")
    tooltipText: (profileState === "battery")
        ? Translation.tr("Battery Saver: CPU 3.1GHz cap, GPU 1200MHz lock, 60Hz")
        : Translation.tr("AC Performance: CPU 4.5GHz Boost, Full GPU, 144Hz")

    mainAction: () => {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "toggle"]);
        checkTimer.restart();
    }

    altAction: () => {
        Quickshell.execDetached(["sudo", "/usr/local/bin/power-profile-manager", "auto"]);
        checkTimer.restart();
    }

    Process {
        id: readStateProc
        running: true
        command: ["cat", "/run/power-profile-state"]
        stdout: SplitParser {
            onRead: data => {
                const s = data.trim();
                if (s === "battery" || s === "ac") {
                    root.profileState = s;
                }
            }
        }
    }

    Timer {
        id: checkTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!readStateProc.running) {
                readStateProc.running = true;
            }
        }
    }
}
