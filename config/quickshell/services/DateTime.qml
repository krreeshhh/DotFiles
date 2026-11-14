// Date, time and uptime.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property date now: new Date()
    property real uptimeSeconds: 0

    readonly property string time: Qt.formatDateTime(now, "hh:mm")
    readonly property string timeWithSeconds: Qt.formatDateTime(now, "hh:mm:ss")
    readonly property string longDate: Qt.formatDateTime(now, "ddd, dd/MM")
    readonly property string shortDate: Qt.formatDateTime(now, "dd/MM")
    readonly property string dateWithYear: Qt.formatDateTime(now, "dd/MM/yyyy")
    readonly property string collapsedCalendarFormat: Qt.formatDateTime(now, "ddd, dd/MM")

    readonly property string uptime: {
        const s = Math.floor(uptimeSeconds);
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            root.uptimeSeconds = root.uptimeSeconds + 1;
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        Component.onCompleted: {
            try {
                root.uptimeSeconds = parseFloat(uptimeFile.text().split(" ")[0]) || 0;
            } catch (e) {}
        }
    }
}
