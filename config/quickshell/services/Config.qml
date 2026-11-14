// Lightweight persisted configuration (subset of end-4's Config).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string path: "/home/Krish/.config/quickshell/config.json"

    readonly property var defaults: ({
        bar: {
            cornerStyle: 0,                    // 0 = hug (fillet), 1 = float (pill island)
            showBackground: true,
            verbose: true,
            bottom: false,
            autoHide: {
                enable: false,
                showWhenPressingSuper: { enable: true, delay: 100 },
                hoverRegionWidth: 8,
                pushWindows: false
            },
            utilButtons: {
                showScreenSnip: true,
                showScreenRecord: false,
                showColorPicker: true,
                showKeyboardToggle: false,
                showMicToggle: true,
                showDarkModeToggle: false,
                showPerformanceProfileToggle: true,
                showWeather: false
            },
            resources: {
                alwaysShowCpu: false,
                alwaysShowSwap: false,
                memoryWarningThreshold: 85,
                swapWarningThreshold: 60,
                cpuWarningThreshold: 90
            }
        },
        sidebar: {
            keepRightSidebarLoaded: true,
            quickSliders: { enable: true, showBrightness: true, showVolume: true, showMic: false },
            quickToggles: {
                style: "android",
                android: {
                    columns: 5,
                    toggles: [
                        { size: 2, type: "network" },
                        { size: 2, type: "bluetooth" },
                        { size: 1, type: "idleInhibitor" },
                        { size: 1, type: "mic" },
                        { size: 2, type: "audio" },
                        { size: 2, type: "nightLight" }
                    ]
                }
            }
        },
        search: {
            engineBaseUrl: "https://www.google.com/search?q=",
            prefix: {
                action: "/",
                app: ">",
                clipboard: ";",
                emojis: ":",
                math: "=",
                shellCommand: "$",
                webSearch: "?"
            }
        },
        overview: { enable: true, rows: 2, columns: 5 },
        media: { filterDuplicatePlayers: true },
        time: { format: "hh:mm", longDateFormat: "ddd, dd/MM" }
    })

    property bool ready: false
    property var options: defaults

    FileView {
        id: configFile
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.load()
        onTextChanged: root.load()
    }

    function deepMerge(base, override) {
        const out = Array.isArray(base) ? base.slice() : Object.assign({}, base);
        if (!override || typeof override !== "object") return out;
        for (const key in override) {
            const val = override[key];
            if (val && typeof val === "object" && !Array.isArray(val)
                && out[key] && typeof out[key] === "object" && !Array.isArray(out[key])) {
                out[key] = deepMerge(out[key], val);
            } else {
                out[key] = val;
            }
        }
        return out;
    }

    function load() {
        try {
            const parsed = JSON.parse(configFile.text());
            options = deepMerge(defaults, parsed);
        } catch (e) {
            options = deepMerge(defaults, {});
        }
        if (!ready) ready = true;
    }

    function save() {
        try {
            configFile.setText(JSON.stringify(options, null, 2));
        } catch (e) {}
    }

    function set(path, value) {
        const parts = path.split(".");
        let obj = options;
        for (let i = 0; i < parts.length - 1; i++) {
            if (!obj[parts[i]] || typeof obj[parts[i]] !== "object") obj[parts[i]] = {};
            obj = obj[parts[i]];
        }
        obj[parts[parts.length - 1]] = value;
        // Reassign so bindings see the change.
        options = Object.assign({}, options);
        save();
    }

    Component.onCompleted: load()
}
