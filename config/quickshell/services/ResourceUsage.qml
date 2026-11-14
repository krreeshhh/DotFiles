// Polled CPU / RAM / swap usage.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property real memoryTotal: 1
    property real memoryFree: 0
    readonly property real memoryUsed: Math.max(0, memoryTotal - memoryFree)
    readonly property real memoryUsedPercentage: memoryUsed / Math.max(1, memoryTotal)

    property real swapTotal: 1
    property real swapFree: 0
    readonly property real swapUsed: Math.max(0, swapTotal - swapFree)
    readonly property real swapUsedPercentage: swapTotal > 0 ? swapUsed / swapTotal : 0

    property real cpuUsage: 0
    property var previousCpuStats: null

    readonly property int historyLength: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var swapHistory: []

    function push(history, value) {
        const next = history.concat([value]);
        return next.length > historyLength ? next.slice(next.length - historyLength) : next;
    }

    function update() {
        try {
            const mem = meminfo.text();
            memoryTotal = Number(mem.match(/MemTotal:\s*(\d+)/)?.[1] ?? 1);
            memoryFree = Number(mem.match(/MemAvailable:\s*(\d+)/)?.[1] ?? 0);
            swapTotal = Number(mem.match(/SwapTotal:\s*(\d+)/)?.[1] ?? 0);
            swapFree = Number(mem.match(/SwapFree:\s*(\d+)/)?.[1] ?? 0);

            const stat = procStat.text();
            const line = stat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (line) {
                const stats = line.slice(1).map(Number);
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3];
                if (previousCpuStats) {
                    const dt = total - previousCpuStats.total;
                    const di = idle - previousCpuStats.idle;
                    cpuUsage = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
                }
                previousCpuStats = { total, idle };
            }

            cpuHistory = push(cpuHistory, cpuUsage);
            memoryHistory = push(memoryHistory, memoryUsedPercentage);
            swapHistory = push(swapHistory, swapUsedPercentage);
        } catch (e) {}
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: procStat; path: "/proc/stat"; blockLoading: true }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            procStat.reload();
            root.update();
        }
    }
}
