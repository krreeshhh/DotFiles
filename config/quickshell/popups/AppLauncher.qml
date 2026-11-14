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
    BackgroundEffect.blurRegion: Region { item: card }

    property bool shown: false
    property string currentView: "main" // "main" | "webapps"
    property string searchText: ""
    property int selectedIndex: 0
    property var webappsList: []

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

    function refreshWebApps() {
        webappProc.running = true;
    }


    Component.onCompleted: {
        refreshWebApps();
    }

    function openMenu(targetView) {
        closeTimer.stop();
        root.searchText = "";
        searchField.text = "";
        root.currentView = (targetView && typeof targetView === "string" && targetView.length > 0) ? targetView : "main";
        root.selectedIndex = 0;
        refreshWebApps();
        root.visible = true;
        root.shown = true;
        searchField.forceActiveFocus();
    }
    function setSearch(query) {
        openMenu();
        searchField.text = query || "";
        root.searchText = query || "";
        root.selectedIndex = 0;
        itemList.positionViewAtBeginning();
    }

    function selectIndex(idx) {
        if (!root.shown) openMenu();
        root.selectedIndex = Math.max(0, Math.min(itemList.count - 1, idx));
        itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
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

    function getFallbackGlyph(item) {
        if (!item) return "󰣆";
        if (item.type === "folder" || item.isFolder) return "󰉋";
        if (item.type === "webapp") return "󰖟";
        if (item.type === "delete_webapp") return "󰩺";
        if (item.action === "create") return "󰐕";
        if (item.action === "back" || item.action === "back_to_webapps") return "󰁮";

        var n = (item.name || "").toLowerCase();
        var s = (item.subtitle || "").toLowerCase();
        var combined = n + " " + s;

        if (combined.includes("terminal") || combined.includes("cli") || combined.includes("bash") || combined.includes("zsh") || combined.includes("ghostty") || combined.includes("kitty") || combined.includes("alacritty") || combined.includes("console")) return "󰆍";
        if (combined.includes("android") || combined.includes("studio") || combined.includes("code") || combined.includes("dev") || combined.includes("ide") || combined.includes("nvim") || combined.includes("editor")) return "󰅩";
        if (combined.includes("network") || combined.includes("wifi") || combined.includes("connection") || combined.includes("bluetooth") || combined.includes("vpn")) return "󰖩";
        if (combined.includes("setting") || combined.includes("config") || combined.includes("preference") || combined.includes("control") || combined.includes("tuf") || combined.includes("armoury")) return "󰒓";
        if (combined.includes("audio") || combined.includes("sound") || combined.includes("music") || combined.includes("volume")) return "󰝚";
        if (combined.includes("video") || combined.includes("movie") || combined.includes("cine") || combined.includes("player")) return "󰐌";
        if (combined.includes("browser") || combined.includes("web") || combined.includes("internet") || combined.includes("brave") || combined.includes("chrome") || combined.includes("firefox")) return "󰖟";
        if (combined.includes("file") || combined.includes("folder") || combined.includes("archive") || combined.includes("roller") || combined.includes("rename") || combined.includes("nautilus") || combined.includes("yazi")) return "󰉋";
        if (combined.includes("clip") || combined.includes("paste") || combined.includes("history")) return "󰅍";
        if (combined.includes("image") || combined.includes("photo") || combined.includes("view") || combined.includes("gimp")) return "󰋩";
        if (combined.includes("chat") || combined.includes("telegram") || combined.includes("fagram") || combined.includes("discord") || combined.includes("message")) return "󰭹";
        return "󰣆";
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
            root.refreshWebApps();
        }
    }

    // Helper to calculate filtered items with reactive dependency tracking
    function getFilteredItems(view, queryStr, webapps, allDesktopApps) {
        var q = (queryStr || "").trim().toLowerCase();
        var results = [];
        var apps = allDesktopApps || [];
        var waList = webapps || [];
        // Gather any webapps found in DesktopEntries
        var desktopWebApps = [];
        for (var d = 0; d < apps.length; d++) {
            var de = apps[d];
            if (de && de.id && de.id.startsWith("webapp-")) {
                desktopWebApps.push(de);
            }
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

        if (q === "") {
            // 1. Pinned Web Apps folder
            results.push({
                type: "folder",
                folderId: "webapps",
                isFolder: true,
                name: "Web Apps",
                icon: "folder",
                subtitle: "Folder (" + countWebApps + " web apps)"
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
            root.currentView = item.folderId || "webapps";
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
        var items = root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values);
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
        width: 540
        height: 520
        anchors.centerIn: parent
        radius: 16
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1.5
        clip: true

        opacity: root.shown ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 160 : 120
                easing.type: Easing.OutCubic
            }
        }

        // Catch clicks inside card so they don't dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // 1. Top Search Header
        Rectangle {
            id: searchHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                // Search Icon
                Text {
                    text: root.currentView.startsWith("remove") ? "󰩺" : (root.currentView === "webapps" ? "󰖟" : "󰍉")
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    color: root.currentView.startsWith("remove") ? Theme.colorError : (root.currentView === "webapps" ? Theme.secondary : Theme.primary)
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
                            if (root.currentView === "remove_webapps") return "Select web app to remove or press Left / Escape..";
                            if (root.currentView === "webapps") return "Search Web Apps or press Left to go back..";
                            return "Search applications, web apps, tools..";
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
                        var items = root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values);
                        if (items.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < items.length) {
                            var cur = items[root.selectedIndex];
                            if (cur && (cur.type === "folder" || cur.isFolder)) {
                                root.activateItem(cur);
                                event.accepted = true;
                                return;
                            }
                        }
                        root.launchCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onLeftPressed: (event) => {
                        if (root.currentView === "remove_webapps") {
                            root.currentView = "webapps";
                            root.searchText = "";
                            searchField.text = "";
                            root.selectedIndex = 0;
                            event.accepted = true;
                        } else if (root.currentView === "webapps") {
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
                        if (event.key === Qt.Key_Tab) {
                            var count = itemList.count;
                            if (count > 0) {
                                if (root.selectedIndex < count - 1) root.selectedIndex++;
                                else root.selectedIndex = 0;
                                itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Backtab) {
                            var count = itemList.count;
                            if (count > 0) {
                                if (root.selectedIndex > 0) root.selectedIndex--;
                                else root.selectedIndex = count - 1;
                                itemList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp) {
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

                // Mode pill badge when in webapps or remove mode
                Rectangle {
                    visible: root.currentView !== "main"
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: modeLabel.implicitWidth + 14
                    radius: 6
                    color: root.currentView === "remove_webapps" ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.25) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.25)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: root.currentView === "remove_webapps" ? "Remove Mode" : "Web Apps"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: root.currentView === "remove_webapps" ? Theme.colorError : Theme.secondary
                    }
                }

                // Clear button
                Rectangle {
                    visible: searchField.text.length > 0
                    width: 22
                    height: 22
                    radius: 11
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
        }

        // Top Divider Line
        Rectangle {
            id: topDivider
            anchors.top: searchHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            color: Theme.popupBorder
            opacity: 0.6
        }

        // 2. Bottom Footer / Status Bar
        Rectangle {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38
            color: "transparent"

            // Footer Divider
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Theme.popupBorder
                opacity: 0.4
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18

                // Result count
                Text {
                    text: {
                        var c = itemList.count;
                        if (root.currentView === "webapps") return c + (c === 1 ? " web app" : " web apps");
                        if (root.currentView === "remove_webapps") return "Select an app to uninstall";
                        if (root.searchText.length > 0) return c + (c === 1 ? " match" : " matches");
                        return c + " applications";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.colOnSurfaceVariant
                    opacity: 0.8
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Keyboard hints
                Row {
                    spacing: 12
                    Layout.alignment: Qt.AlignVCenter

                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 20; height: 18; radius: 4
                            color: Theme.surfaceVariant
                            Text {
                                anchors.centerIn: parent
                                text: "↑↓"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "navigate"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colOnSurfaceVariant
                            opacity: 0.7
                        }
                    }

                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 20; height: 18; radius: 4
                            color: Theme.surfaceVariant
                            Text {
                                anchors.centerIn: parent
                                text: "↵"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "launch"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colOnSurfaceVariant
                            opacity: 0.7
                        }
                    }

                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 28; height: 18; radius: 4
                            color: Theme.surfaceVariant
                            Text {
                                anchors.centerIn: parent
                                text: "esc"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                color: Theme.colOnSurfaceVariant
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "close"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.colOnSurfaceVariant
                            opacity: 0.7
                        }
                    }
                }
            }
        }

        // 3. Application & Results List
        ListView {
            id: itemList
            anchors.top: topDivider.bottom
            anchors.bottom: footerBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            clip: true
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds

            model: root.getFilteredItems(root.currentView, root.searchText, root.webappsList, DesktopEntries.applications.values)

            delegate: Rectangle {
                id: itemDelegate
                width: itemList.width
                height: 46
                radius: 8
                property bool isSelected: index === root.selectedIndex
                property bool isDelete: modelData.type === "delete_webapp"

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
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        // Fallback glyph tile when system icon is missing or loading
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: itemDelegate.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : Theme.surfaceVariant
                            visible: !appIcon.visible || appIcon.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: root.getFallbackGlyph(modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                color: itemDelegate.isSelected ? (itemDelegate.isDelete ? Theme.colorError : Theme.primary) : Theme.colOnSurfaceVariant
                            }
                        }

                        // System icon
                        IconImage {
                            id: appIcon
                            anchors.fill: parent
                            source: {
                                var ic = modelData.icon || "";
                                if (!ic) return Quickshell.iconPath("application-x-executable");
                                if (ic.startsWith("/")) return "file://" + ic;
                                return Quickshell.iconPath(ic, "application-x-executable");
                            }
                            mipmap: true
                            visible: status === Image.Ready
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
                        visible: modelData.type === "folder" || modelData.type === "webapp" || modelData.type === "delete_webapp" || (modelData.type === "action" && modelData.action !== "back" && modelData.action !== "back_to_webapps")
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: badgeText.implicitWidth + 12
                        radius: 4
                        color: itemDelegate.isDelete ? (itemDelegate.isSelected ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.35) : Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.18)) : (itemDelegate.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Theme.surfaceVariant)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: {
                                if (modelData.type === "delete_webapp") return "Remove ✕";
                                if (modelData.type === "folder") return "Folder ›";
                                if (modelData.type === "webapp") return "PWA";
                                if (modelData.action === "create") return "Add";
                                if (modelData.action === "remove") return "Remove";
                                return "";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: itemDelegate.isDelete ? Theme.colorError : (itemDelegate.isSelected ? Theme.primary : Theme.colOnSurfaceVariant)
                        }
                    }
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

        // 4. Empty state placeholder overlay
        Item {
            anchors.fill: itemList
            visible: itemList.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰮗"
                    font.family: Theme.fontFamily
                    font.pixelSize: 36
                    color: Theme.colOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                Text {
                    text: root.currentView === "webapps" ? "No web apps installed" : "No applications found"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.colOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Try searching with a different term"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.colOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.7
                }
            }
        }
    }
}
