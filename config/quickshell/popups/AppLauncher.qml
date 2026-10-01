import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import ".."

PanelWindow {
    id: root
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell"

    property bool shown: false
    property string currentView: "main" // "main" | "webapps" | "plugins"
    property string searchText: ""
    property int selectedIndex: 0
    property var webappsList: []
    property var pluginsList: []

    onCurrentViewChanged: {
        root.selectedIndex = 0;
        itemList.positionViewAtBeginning();
    }

    // Process to fetch installed Web Apps dynamically
    Process {
        id: webappProc
        command: ["python3", "-c", "import sys, json, os; sys.path.insert(0, '/home/Krish/.config/my-desktop/launcher'); import webapp_manager; print(json.dumps(webapp_manager.list_webapps()))"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line.trim());
                    if (Array.isArray(data)) {
                        root.webappsList = data;
                    }
                } catch(e) {}
            }
        }
    }

    // Process to fetch installed Omarchy Plugins dynamically
    Process {
        id: pluginProc
        command: ["python3", "-c", "import sys, json, os; sys.path.insert(0, '/home/Krish/.config/my-desktop/launcher'); import plugin_manager; print(json.dumps(plugin_manager.list_plugins()))"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line.trim());
                    if (Array.isArray(data)) {
                        root.pluginsList = data;
                    }
                } catch(e) {}
            }
        }
    }

    function refreshWebApps() {
        webappProc.running = true;
    }

    function refreshPlugins() {
        pluginProc.running = true;
    }

    Component.onCompleted: {
        refreshWebApps();
        refreshPlugins();
    }

    function openMenu(targetView) {
        closeTimer.stop();
        root.searchText = "";
        searchField.text = "";
        root.currentView = (targetView && typeof targetView === "string" && targetView.length > 0) ? targetView : "main";
        root.selectedIndex = 0;
        refreshWebApps();
        refreshPlugins();
        root.visible = true;
        root.shown = true;
        searchField.forceActiveFocus();
    }

    function closeMenu() {
        if (!root.shown) return;
        root.shown = false;
        closeTimer.restart();
    }

    function closeImmediate() {
        closeTimer.stop();
        root.shown = false;
        root.visible = false;
        root.searchText = "";
        searchField.text = "";
    }

    function toggle() {
        if (root.shown && root.visible) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    Timer {
        id: closeTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (!root.shown) {
                root.visible = false;
            }
        }
    }

    Timer {
        id: removeRefreshTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.refreshPlugins();
            root.refreshWebApps();
        }
    }

    // Helper to calculate filtered items with reactive dependency tracking
    function getFilteredItems(view, queryStr, webapps, allDesktopApps, plugins) {
        var q = (queryStr || "").trim().toLowerCase();
        var results = [];
        var apps = allDesktopApps || [];
        var waList = webapps || [];
        var pList = plugins || [];

        // Gather any webapps found in DesktopEntries
        var desktopWebApps = [];
        for (var d = 0; d < apps.length; d++) {
            var de = apps[d];
            if (de && de.id && de.id.startsWith("webapp-")) {
                desktopWebApps.push(de);
            }
        }

        if (view === "plugins") {
            // -------------------------------------------------------------
            // PLUGINS VIEW (Omarchy)
            // -------------------------------------------------------------
            if (q === "") {
                results.push({
                    type: "action",
                    action: "back",
                    name: ".. Back",
                    icon: "go-previous-symbolic",
                    subtitle: "Return to all applications"
                });
                results.push({
                    type: "action",
                    action: "install_plugin",
                    name: "+ Install Plugin (omarchy plugin add)",
                    icon: "list-add-symbolic",
                    subtitle: "Install Quickshell plugin from Git repository"
                });
                if (pList.length > 0) {
                    results.push({
                        type: "action",
                        action: "remove_plugin",
                        name: "- Remove Plugin",
                        icon: "user-trash-symbolic",
                        subtitle: "Uninstall an existing Omarchy plugin"
                    });
                }
                results.push({
                    type: "action",
                    action: "open_plugins_dir",
                    name: "📁 Open Plugins Folder",
                    icon: "folder-open-symbolic",
                    subtitle: "~/.config/quickshell/plugins"
                });
            } else {
                results.push({
                    type: "action",
                    action: "back",
                    name: ".. Back",
                    icon: "go-previous-symbolic",
                    subtitle: "Return to all applications"
                });
            }

            for (var p = 0; p < pList.length; p++) {
                var pl = pList[p];
                if (!pl) continue;
                var pName = pl.name || pl.dir || "Plugin";
                var pDesc = pl.description || "";
                var pVer = pl.version ? "v" + pl.version : "";
                var pAuthor = pl.author ? "by " + pl.author : "";
                var pStatus = pl.enabled ? "Active" : "Installed";
                var subParts = [pStatus, pVer, pAuthor].filter(function(x) { return x && x.length > 0; });
                var sub = subParts.join(" • ");
                if (pDesc) {
                    sub = sub ? (sub + " — " + pDesc) : pDesc;
                }

                if (q === "" || pName.toLowerCase().includes(q) || pDesc.toLowerCase().includes(q) || (pl.id && pl.id.toLowerCase().includes(q)) || (pl.dir && pl.dir.toLowerCase().includes(q))) {
                    results.push({
                        type: "plugin",
                        name: pName,
                        icon: pl.icon || "preferences-plugin-symbolic",
                        subtitle: sub,
                        plugin: pl
                    });
                }
            }

            return results;
        }

        if (view === "webapps") {
            // -------------------------------------------------------------
            // WEB APPS VIEW
            // -------------------------------------------------------------
            if (q === "") {
                results.push({
                    type: "action",
                    action: "back",
                    name: ".. Back",
                    icon: "go-previous-symbolic",
                    subtitle: "Return to all applications"
                });
                results.push({
                    type: "action",
                    action: "create",
                    name: "+ Create Web App (PWA)",
                    icon: "list-add-symbolic",
                    subtitle: "Install website as desktop app"
                });
                if (waList.length > 0 || desktopWebApps.length > 0) {
                    results.push({
                        type: "action",
                        action: "remove",
                        name: "- Remove Web App",
                        icon: "user-trash-symbolic",
                        subtitle: "Uninstall an existing web app"
                    });
                }
            } else {
                results.push({
                    type: "action",
                    action: "back",
                    name: ".. Back",
                    icon: "go-previous-symbolic",
                    subtitle: "Return to all applications"
                });
            }

            var seenWebApps = {};

            // Add from webappsList
            for (var w = 0; w < waList.length; w++) {
                var wa = waList[w];
                var wName = wa.name || "";
                var wUrl = wa.url || "";
                var wCat = wa.category || "Web App";
                if (q === "" || wName.toLowerCase().includes(q) || wUrl.toLowerCase().includes(q) || wCat.toLowerCase().includes(q)) {
                    seenWebApps[wName.toLowerCase()] = true;
                    results.push({
                        type: "webapp",
                        name: wName,
                        icon: wa.icon || "web-browser",
                        subtitle: wCat + " • " + wUrl,
                        webapp: wa
                    });
                }
            }

            // Also add any from desktopWebApps not already added
            for (var dw = 0; dw < desktopWebApps.length; dw++) {
                var dwa = desktopWebApps[dw];
                if (!seenWebApps[dwa.name.toLowerCase()]) {
                    if (q === "" || dwa.name.toLowerCase().includes(q)) {
                        results.push({
                            type: "webapp",
                            name: dwa.name,
                            icon: dwa.icon || "web-browser",
                            subtitle: "Web App • " + (dwa.genericName || dwa.comment || ""),
                            entry: dwa
                        });
                    }
                }
            }

            return results;
        }

        if (view === "remove_plugins") {
            // -------------------------------------------------------------
            // REMOVE PLUGINS VIEW
            // -------------------------------------------------------------
            results.push({
                type: "action",
                action: "back_to_plugins",
                name: ".. Cancel / Back",
                icon: "go-previous-symbolic",
                subtitle: "Return to plugins folder"
            });

            if (pList.length === 0) {
                results.push({
                    type: "notice",
                    name: "No Plugins Installed",
                    icon: "dialog-information-symbolic",
                    subtitle: "Install plugins from the Plugins menu"
                });
            } else {
                for (var rp = 0; rp < pList.length; rp++) {
                    var rpl = pList[rp];
                    if (!rpl) continue;
                    var rpName = rpl.name || rpl.dir || "Plugin";
                    var rpStatus = rpl.enabled ? "Active" : "Installed";
                    if (q === "" || rpName.toLowerCase().includes(q) || (rpl.dir && rpl.dir.toLowerCase().includes(q))) {
                        results.push({
                            type: "delete_plugin",
                            name: rpName + " (" + rpStatus + ")",
                            icon: rpl.icon || "user-trash-symbolic",
                            subtitle: "Click to uninstall " + (rpl.path || rpl.dir || rpName),
                            plugin: rpl
                        });
                    }
                }
            }
            return results;
        }

        if (view === "remove_webapps") {
            // -------------------------------------------------------------
            // REMOVE WEB APPS VIEW
            // -------------------------------------------------------------
            results.push({
                type: "action",
                action: "back_to_webapps",
                name: ".. Cancel / Back",
                icon: "go-previous-symbolic",
                subtitle: "Return to web apps folder"
            });

            var seenDelWa = {};
            var delList = [];
            for (var rw = 0; rw < waList.length; rw++) {
                var rwa = waList[rw];
                if (rwa && rwa.name) {
                    seenDelWa[rwa.name.toLowerCase()] = true;
                    delList.push(rwa);
                }
            }
            for (var rdw = 0; rdw < desktopWebApps.length; rdw++) {
                var rdwa = desktopWebApps[rdw];
                if (rdwa && rdwa.name && !seenDelWa[rdwa.name.toLowerCase()]) {
                    delList.push({
                        name: rdwa.name,
                        icon: rdwa.icon || "web-browser",
                        file: rdwa.filePath || "",
                        url: rdwa.comment || "",
                        category: "Web App"
                    });
                }
            }

            if (delList.length === 0) {
                results.push({
                    type: "notice",
                    name: "No Web Applications Installed",
                    icon: "dialog-information-symbolic",
                    subtitle: "Create web apps from the Web Apps menu"
                });
            } else {
                for (var k = 0; k < delList.length; k++) {
                    var kwa = delList[k];
                    var kwaName = kwa.name || "Web App";
                    var kwaUrl = kwa.url || "";
                    if (q === "" || kwaName.toLowerCase().includes(q) || kwaUrl.toLowerCase().includes(q)) {
                        results.push({
                            type: "delete_webapp",
                            name: kwaName,
                            icon: kwa.icon || "user-trash-symbolic",
                            subtitle: "Click to uninstall " + (kwaUrl ? "(" + kwaUrl + ")" : "web application"),
                            webapp: kwa
                        });
                    }
                }
            }
            return results;
        }

        // -----------------------------------------------------------------
        // MAIN VIEW
        // -----------------------------------------------------------------
        var countWebApps = Math.max(waList.length, desktopWebApps.length);
        var countPlugins = pList.length;

        if (q === "") {
            // 1. Pinned Web Apps folder
            results.push({
                type: "folder",
                folderId: "webapps",
                isFolder: true,
                name: "Web Apps",
                icon: "folder-symbolic",
                subtitle: "Folder (" + countWebApps + " web apps)"
            });

            // 2. Pinned Plugins folder (Omarchy)
            results.push({
                type: "folder",
                folderId: "plugins",
                isFolder: true,
                name: "Plugins",
                icon: "folder-symbolic",
                subtitle: "Folder (" + countPlugins + " Omarchy plugin" + (countPlugins === 1 ? "" : "s") + ")"
            });

            // 3. All installed system apps
            var normalApps = [];
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i];
                if (!app || !app.name) continue;
                if (app.id === "webapp-manager") continue;
                // Keep standalone webapps neatly inside the Web Apps folder
                if (app.id && app.id.startsWith("webapp-")) continue;

                normalApps.push({
                    type: "app",
                    name: app.name,
                    icon: app.icon || "application-x-executable",
                    subtitle: app.genericName || app.comment || (app.categories ? app.categories.join(", ") : ""),
                    entry: app
                });
            }

            normalApps.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
            results = results.concat(normalApps);
        } else {
            // Search mode: match apps, webapps, plugins, and folders
            if ("web apps".includes(q) || "pwa".includes(q) || "websites".includes(q)) {
                results.push({
                    type: "folder",
                    folderId: "webapps",
                    isFolder: true,
                    name: "Web Apps",
                    icon: "folder",
                    subtitle: "Folder (" + countWebApps + " web apps)"
                });
            }

            if ("plugins".includes(q) || "omarchy".includes(q) || "plugin".includes(q) || "addons".includes(q) || "extensions".includes(q)) {
                results.push({
                    type: "folder",
                    folderId: "plugins",
                    isFolder: true,
                    name: "Plugins",
                    icon: "folder",
                    subtitle: "Folder (" + countPlugins + " Omarchy plugin" + (countPlugins === 1 ? "" : "s") + ")"
                });
            }

            var scored = [];

            // Score desktop apps
            for (var j = 0; j < apps.length; j++) {
                var a = apps[j];
                if (!a || !a.name || a.id === "webapp-manager") continue;
                var nameL = a.name.toLowerCase();
                var genL = (a.genericName || "").toLowerCase();
                var commL = (a.comment || "").toLowerCase();
                var catsL = a.categories ? a.categories.join(" ").toLowerCase() : "";
                var execL = (a.execString || "").toLowerCase();

                var score = 0;
                if (nameL === q) score = 100;
                else if (nameL.startsWith(q)) score = 80;
                else if (nameL.includes(q)) score = 60;
                else if (genL.includes(q)) score = 40;
                else if (catsL.includes(q)) score = 30;
                else if (commL.includes(q)) score = 20;
                else if (execL.includes(q)) score = 10;

                if (score > 0) {
                    scored.push({
                        score: score,
                        item: {
                            type: a.id && a.id.startsWith("webapp-") ? "webapp" : "app",
                            name: a.name,
                            icon: a.icon || "application-x-executable",
                            subtitle: a.genericName || a.comment || (a.categories ? a.categories.join(", ") : ""),
                            entry: a
                        }
                    });
                }
            }

            // Score web apps
            for (var k = 0; k < waList.length; k++) {
                var waItem = waList[k];
                var waName = (waItem.name || "").toLowerCase();
                var waUrl = (waItem.url || "").toLowerCase();
                var waCat = (waItem.category || "").toLowerCase();

                var wScore = 0;
                if (waName === q) wScore = 95;
                else if (waName.startsWith(q)) wScore = 75;
                else if (waName.includes(q)) wScore = 55;
                else if (waUrl.includes(q)) wScore = 35;
                else if (waCat.includes(q)) wScore = 25;

                if (wScore > 0) {
                    var alreadyWa = scored.some(s => s.item.name.toLowerCase() === waItem.name.toLowerCase());
                    if (!alreadyWa) {
                        scored.push({
                            score: wScore,
                            item: {
                                type: "webapp",
                                name: waItem.name,
                                icon: waItem.icon || "web-browser",
                                subtitle: (waItem.category || "Web App") + " • " + (waItem.url || ""),
                                webapp: waItem
                            }
                        });
                    }
                }
            }

            // Score Omarchy plugins
            for (var m = 0; m < pList.length; m++) {
                var plItem = pList[m];
                var plName = (plItem.name || "").toLowerCase();
                var plDir = (plItem.dir || "").toLowerCase();
                var plDesc = (plItem.description || "").toLowerCase();
                var plId = (plItem.id || "").toLowerCase();

                var plScore = 0;
                if (plName === q || plDir === q) plScore = 95;
                else if (plName.startsWith(q) || plDir.startsWith(q)) plScore = 75;
                else if (plName.includes(q) || plDir.includes(q)) plScore = 55;
                else if (plDesc.includes(q) || plId.includes(q)) plScore = 35;

                if (plScore > 0) {
                    var pVer = plItem.version ? "v" + plItem.version : "";
                    var pAuthor = plItem.author ? "by " + plItem.author : "";
                    var pStatus = plItem.enabled ? "Active" : "Installed";
                    var subParts = [pStatus, pVer, pAuthor].filter(function(x) { return x && x.length > 0; });
                    var sub = subParts.join(" • ");
                    if (plItem.description) {
                        sub = sub ? (sub + " — " + plItem.description) : plItem.description;
                    }

                    var alreadyPl = scored.some(s => s.item.name.toLowerCase() === plItem.name.toLowerCase());
                    if (!alreadyPl) {
                        scored.push({
                            score: plScore,
                            item: {
                                type: "plugin",
                                name: plItem.name,
                                icon: plItem.icon || "preferences-plugin-symbolic",
                                subtitle: sub,
                                plugin: plItem
                            }
                        });
                    }
                }
            }

            scored.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name));
            for (var s = 0; s < scored.length; s++) {
                results.push(scored[s].item);
            }
        }

        return results;
    }

    function activateItem(item) {
        if (!item) return;

        if (item.type === "folder" || item.isFolder) {
            root.currentView = item.folderId || (item.name === "Plugins" ? "plugins" : "webapps");
            root.searchText = "";
            searchField.text = "";
            root.selectedIndex = 0;
            return;
        }

        if (item.type === "action") {
            if (item.action === "back") {
                root.currentView = "main";
                root.searchText = "";
                searchField.text = "";
                root.selectedIndex = 0;
            } else if (item.action === "back_to_plugins") {
                root.currentView = "plugins";
                root.searchText = "";
                searchField.text = "";
                root.selectedIndex = 0;
            } else if (item.action === "back_to_webapps") {
                root.currentView = "webapps";
                root.searchText = "";
                searchField.text = "";
                root.selectedIndex = 0;
            } else if (item.action === "create") {
                root.closeImmediate();
                Quickshell.execDetached(["python3", "/home/Krish/.config/my-desktop/launcher/webapp_manager.py", "interactive"]);
            } else if (item.action === "remove") {
                root.currentView = "remove_webapps";
                root.searchText = "";
                searchField.text = "";
                root.selectedIndex = 0;
            } else if (item.action === "install_plugin") {
                root.closeImmediate();
                Quickshell.execDetached(["python3", "/home/Krish/.config/my-desktop/launcher/plugin_manager.py", "install"]);
            } else if (item.action === "remove_plugin") {
                root.currentView = "remove_plugins";
                root.searchText = "";
                searchField.text = "";
                root.selectedIndex = 0;
            } else if (item.action === "open_plugins_dir") {
                root.closeImmediate();
                Quickshell.execDetached(["xdg-open", "/home/Krish/.config/quickshell/plugins"]);
            }
            return;
        }

        if (item.type === "delete_plugin") {
            if (item.plugin && item.plugin.dir) {
                var delDir = item.plugin.dir;
                var delName = item.plugin.name || delDir;
                Quickshell.execDetached(["python3", "-c", "import sys, subprocess, os; os.environ['PATH'] = os.path.expanduser('~/.local/bin:') + os.environ.get('PATH', ''); subprocess.run(['omarchy', 'plugin', 'remove', sys.argv[1]]); subprocess.run(['notify-send', 'Plugin Removed', 'Uninstalled plugin ' + sys.argv[2], '-i', 'user-trash-symbolic'])", delDir, delName]);
                removeRefreshTimer.restart();
            }
            return;
        }

        if (item.type === "delete_webapp") {
            if (item.webapp) {
                var delWaFile = item.webapp.file || "";
                var delWaName = item.webapp.name || "Web App";
                Quickshell.execDetached(["python3", "-c", "import sys, subprocess, os; sys.path.insert(0, '/home/Krish/.config/my-desktop/launcher'); import webapp_manager; webapp_manager.remove_webapp_file(sys.argv[1]) if sys.argv[1] else None; subprocess.run(['notify-send', 'Web App Removed', 'Removed web app ' + sys.argv[2], '-i', 'user-trash-symbolic'])", delWaFile, delWaName]);
                removeRefreshTimer.restart();
            }
            return;
        }

        if (item.type === "plugin") {
            root.closeImmediate();
            if (item.plugin) {
                var p = item.plugin;
                if (p.exec) {
                    if (p.exec.includes("ledge") || p.dir.includes("ledge")) {
                        Quickshell.execDetached([p.exec, "toggle"]);
                    } else {
                        Quickshell.execDetached([p.exec]);
                    }
                } else {
                    Quickshell.execDetached(["xdg-open", p.path || "/home/Krish/.config/quickshell/plugins"]);
                }
            }
            return;
        }

        if (item.type === "webapp") {
            root.closeImmediate();
            if (item.entry) {
                item.entry.execute();
            } else if (item.webapp) {
                var w = item.webapp;
                if (w.file) {
                    var desktopId = w.file.replace(/^.*[\\\/]/, '').replace('.desktop', '');
                    Quickshell.execDetached(["gtk-launch", desktopId]);
                } else if (w.url) {
                    Quickshell.execDetached(["brave-origin", "--app=" + w.url]);
                }
            }
            return;
        }

        if (item.type === "app" && item.entry) {
            root.closeImmediate();
            if (item.entry.runInTerminal) {
                var termCmd = ["ghostty", "-e"];
                var rawCmd = item.entry.command;
                var filtered = [];
                if (rawCmd && rawCmd.length > 0) {
                    for (var i = 0; i < rawCmd.length; i++) {
                        var arg = rawCmd[i];
                        if (typeof arg === "string" && !arg.startsWith("%")) {
                            filtered.push(arg);
                        }
                    }
                }
                if (filtered.length === 0) {
                    filtered = [item.entry.execString ? item.entry.execString.split(" ")[0] : (item.entry.id || "btop")];
                }
                Quickshell.execDetached(termCmd.concat(filtered));
            } else {
                item.entry.execute();
            }
            return;
        }
    }

    function launchCurrentItem() {
        var items = root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values, root.pluginsList);
        if (items.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < items.length) {
            activateItem(items[root.selectedIndex]);
        }
    }

    // Full screen background dismisser
    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        enabled: root.shown
        onClicked: root.closeMenu()
    }

    // Main Launcher Card
    Rectangle {
        id: card
        width: 480
        height: Math.min(540, 72 + Math.max(1, Math.min(8, itemList.count)) * 48 + (itemList.count > 0 ? 12 : 0))
        anchors.centerIn: parent
        radius: 10
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1.5
        clip: true

        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 180 : 130
                easing.type: root.shown ? Easing.OutCubic : Easing.InQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? 200 : 130
                easing.type: root.shown ? Easing.OutCubic : Easing.InQuad
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Catch clicks inside card so they don't dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // 1. Search Bar & Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 10

                // Search Icon
                Text {
                    text: root.currentView.startsWith("remove") ? "󰩺" : (root.currentView === "plugins" ? "󰏗" : (root.currentView === "webapps" ? "󰖟" : "󰍉"))
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: root.currentView.startsWith("remove") ? Theme.colorError : (root.currentView === "plugins" || root.currentView === "webapps" ? Theme.secondary : Theme.primary)
                    Layout.alignment: Qt.AlignVCenter
                }

                // Search Input Field
                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.colOnSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.colOnPrimary
                    clip: true
                    focus: true

                    // Placeholder text
                    Text {
                        anchors.fill: parent
                        text: {
                            if (root.currentView === "remove_plugins") return "Select plugin to remove or press Left / Escape..";
                            if (root.currentView === "remove_webapps") return "Select web app to remove or press Left / Escape..";
                            if (root.currentView === "plugins") return "Search Plugins or press Left to go back..";
                            if (root.currentView === "webapps") return "Search Web Apps or press Left to go back..";
                            return "Go..";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.colOnSurfaceVariant
                        visible: !searchField.text && !searchField.inputMethodComposing
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    onTextChanged: {
                        root.searchText = text;
                        root.selectedIndex = 0;
                        itemList.positionViewAtBeginning();
                    }

                    Keys.onUpPressed: (event) => {
                        var count = itemList.count;
                        if (count > 0) {
                            if (root.selectedIndex > 0) root.selectedIndex--;
                            else root.selectedIndex = count - 1;
                            itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }

                    Keys.onDownPressed: (event) => {
                        var count = itemList.count;
                        if (count > 0) {
                            if (root.selectedIndex < count - 1) root.selectedIndex++;
                            else root.selectedIndex = 0;
                            itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }

                    Keys.onReturnPressed: (event) => {
                        root.launchCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onEnterPressed: (event) => {
                        root.launchCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onRightPressed: (event) => {
                        var items = root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values, root.pluginsList);
                        if (items.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < items.length) {
                            var cur = items[root.selectedIndex];
                            if (cur && (cur.type === "folder" || cur.isFolder)) {
                                root.activateItem(cur);
                                event.accepted = true;
                                return;
                            }
                        }
                        // Default behavior if not folder
                        root.launchCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onLeftPressed: (event) => {
                        if (root.currentView === "remove_plugins") {
                            root.currentView = "plugins";
                            root.searchText = "";
                            searchField.text = "";
                            root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (root.currentView === "remove_webapps") {
                            root.currentView = "webapps";
                            root.searchText = "";
                            searchField.text = "";
                            root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (root.currentView === "webapps" || root.currentView === "plugins") {
                            root.currentView = "main";
                            root.searchText = "";
                            searchField.text = "";
                            root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (searchField.text === "") {
                            root.closeMenu();
                            event.accepted = true;
                        }
                    }

                    Keys.onEscapePressed: (event) => {
                        root.closeMenu();
                        event.accepted = true;
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_PageUp) {
                            var count = itemList.count;
                            if (count > 0) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 6);
                                itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown) {
                            var count = itemList.count;
                            if (count > 0) {
                                root.selectedIndex = Math.min(count - 1, root.selectedIndex + 6);
                                itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        }
                    }
                }

                // Clear button or indicator
                Rectangle {
                    visible: searchField.text.length > 0
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.surfaceVariant
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: Theme.colOnSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = "";
                            searchField.forceActiveFocus();
                        }
                    }
                }
            }

            // Divider Line below Search bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline
                opacity: 0.6
            }

            // 2. Application & Results List
            ListView {
                id: itemList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds

                model: root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values, root.pluginsList)

                delegate: Rectangle {
                    id: itemDelegate
                    width: itemList.width
                    height: 44
                    radius: 6
                    property bool isSelected: index === root.selectedIndex
                    property bool isDelete: modelData.type === "delete_plugin" || modelData.type === "delete_webapp"

                    color: isSelected ? (isDelete ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.22) : Theme.popupSurfaceSelected) : (mouseArea.containsMouse ? Theme.popupSurfaceVariant : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: isDelete ? Theme.colorError : Theme.primary

                    Behavior on color {
                        ColorAnimation { duration: 80 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Icon Component
                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter

                            // For file:// and standard system icon lookup
                            IconImage {
                                anchors.fill: parent
                                source: {
                                    var ic = modelData.icon || "";
                                    if (!ic) return Quickshell.iconPath("application-x-executable", true);
                                    if (ic.startsWith("/")) return "file://" + ic;
                                    return Quickshell.iconPath(ic, true);
                                }
                                mipmap: true
                                visible: source != ""
                            }

                            // Fallback text icon if needed
                            Text {
                                anchors.centerIn: parent
                                text: modelData.type === "folder" ? "󰉋" : (modelData.type === "webapp" ? "󰖟" : (modelData.type === "plugin" ? "󰏗" : "󰵆"))
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                color: itemDelegate.isSelected ? (itemDelegate.isDelete ? Theme.colorError : Theme.primary) : Theme.colOnSurfaceVariant
                                visible: false
                            }
                        }

                        // App Title & Subtitle Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                text: modelData.name || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: itemDelegate.isSelected
                                color: itemDelegate.isSelected ? (itemDelegate.isDelete ? Theme.colorError : Theme.primary) : Theme.colOnSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.subtitle || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: itemDelegate.isSelected ? (itemDelegate.isDelete ? Qt.lighter(Theme.colorError, 1.2) : Qt.lighter(Theme.primary, 1.2)) : Theme.colOnSurfaceVariant
                                elide: Text.ElideRight
                                visible: text.length > 0 && !itemDelegate.isSelected
                                Layout.fillWidth: true
                                opacity: 0.85
                            }
                        }

                        // Right Badge / Indicator
                        Rectangle {
                            visible: modelData.type === "folder" || modelData.type === "webapp" || modelData.type === "plugin" || modelData.type === "delete_plugin" || modelData.type === "delete_webapp" || (modelData.type === "action" && modelData.action !== "back" && modelData.action !== "back_to_plugins" && modelData.action !== "back_to_webapps")
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: badgeText.implicitWidth + 12
                            radius: 4
                            color: itemDelegate.isDelete ? (itemDelegate.isSelected ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.35) : Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.18)) : (itemDelegate.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Theme.surfaceVariant)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: {
                                    if (modelData.type === "delete_plugin" || modelData.type === "delete_webapp") return "Remove ✕";
                                    if (modelData.type === "folder") return "Folder ›";
                                    if (modelData.type === "webapp") return "PWA";
                                    if (modelData.type === "plugin") return modelData.plugin && modelData.plugin.enabled ? "Plugin ✓" : "Plugin";
                                    if (modelData.action === "create" || modelData.action === "install_plugin") return "Add";
                                    if (modelData.action === "open_plugins_dir") return "Open";
                                    if (modelData.action === "remove" || modelData.action === "remove_plugin") return "Remove";
                                    return "";
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: itemDelegate.isDelete ? Theme.colorError : (itemDelegate.isSelected ? Theme.primary : Theme.colOnSurfaceVariant)
                            }
                        }
                    }

                    // Bottom separator line
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        color: Theme.outlineSubtle
                        opacity: itemDelegate.isSelected ? 0 : 0.4
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedIndex = index;
                        }
                        onClicked: {
                            root.activateItem(modelData);
                        }
                    }
                }
            }

            // Empty state placeholder
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: itemList.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰮗"
                        font.family: Theme.fontFamily
                        font.pixelSize: 32
                        color: Theme.colOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.6
                    }

                    Text {
                        text: root.currentView === "plugins" ? "No plugins installed" : (root.currentView === "webapps" ? "No web apps installed" : "No applications found")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.colOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
