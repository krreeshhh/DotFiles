// Backlight control through brightnessctl.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property real brightness: 1.0   // 0..1
    property int maxRaw: 1
    property int raw: 1

    readonly property int percent: Math.round(brightness * 100)

    function refresh() {
        getProc.running = true;
    }

    function setBrightness(value) {
        const v = Math.max(0.01, Math.min(1, value));
        brightness = v;
        Quickshell.execDetached(["brightnessctl", "set", `${Math.round(v * 100)}%`]);
    }

    function increaseBrightness(step) {
        setBrightness(brightness + (step ?? 0.05));
    }

    function decreaseBrightness(step) {
        setBrightness(brightness - (step ?? 0.05));
    }

    // Compatibility with end-4's API: there is one panel here, so every screen
    // gets the same monitor object.
    function getMonitorForScreen(screen) {
        return root;
    }

    Process {
        id: getProc
        command: ["bash", "-c", "b=$(brightnessctl get 2>/dev/null); m=$(brightnessctl max 2>/dev/null); echo \"$b $m\""]
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.trim().split(/\s+/);
                if (parts.length < 2) return;
                const b = parseInt(parts[0]);
                const m = parseInt(parts[1]);
                if (!isNaN(b) && !isNaN(m) && m > 0) {
                    root.raw = b;
                    root.maxRaw = m;
                    root.brightness = b / m;
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
