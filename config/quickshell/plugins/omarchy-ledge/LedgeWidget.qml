import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "LedgeModel.js" as Model

Item {
    id: root

    property string fontFamily: Theme.fontFamily

    readonly property string homeDir: {
        const home = Quickshell.env ? Quickshell.env("HOME") : ""
        return home ? String(home) : ""
    }
    readonly property string stateHomeDir: {
        const stateHome = Quickshell.env ? Quickshell.env("XDG_STATE_HOME") : ""
        return stateHome ? String(stateHome) : ""
    }
    readonly property string statePath: Model.stateFile(homeDir, stateHomeDir)

    property string toast: ""
    property bool dropActive: false
    property bool barDropActive: false
    property bool dragOutActive: false
    property bool opened: popup.open

    function open() { popup.open = true }
    function close() { popup.open = false }
    function toggle() { popup.open = !popup.open }

    // Nerd Font glyphs
    readonly property string glyphLedge: ledgeModel.count > 0 ? "\u{F1296}" : "\u{F1294}" // nf-md-tray_full / nf-md-tray
    readonly property string glyphDrop: "\u{F0120}"    // nf-md-tray_arrow_down
    readonly property string glyphCopyAll: "\u{F0222}" // nf-md-file_multiple
    readonly property string glyphTrash: "\u{F01B4}"   // nf-md-delete
    readonly property string glyphClose: "\u{F0156}"   // nf-md-close
    readonly property string glyphSettings: "\u{F0493}" // nf-md-cog

    implicitWidth: barButton.implicitWidth
    implicitHeight: 36

    property bool pointerHasVisited: false
    property bool settingsOpen: false
    property bool autoCloseWanted: true
    property bool moveAllowed: false
    property int autoCloseDelay: 3

    readonly property bool pointerOnLedge: popup.hovered || mouseArea.containsMouse
    readonly property bool autoCloseArmed: root.opened && root.autoCloseWanted
        && root.pointerHasVisited && !root.pointerOnLedge
        && !root.dragOutActive && !root.barDropActive
        && root.selectionCount === 0 && !root.settingsOpen

    onPointerOnLedgeChanged: if (pointerOnLedge) root.pointerHasVisited = true
    onOpenedChanged: {
        if (!opened) {
            root.pointerHasVisited = false
            root.settingsOpen = false
        }
    }
    onAutoCloseArmedChanged: autoCloseArmed ? autoCloseTimer.restart() : autoCloseTimer.stop()

    Timer {
        id: autoCloseTimer
        interval: root.autoCloseDelay * 1000
        onTriggered: if (root.autoCloseArmed) root.close()
    }

    ListModel {
        id: ledgeModel
    }

    property int selectionCount: 0
    property var selectedPathList: []
    property int selectionAnchor: -1
    property int pinnedCount: 0

    function syncSelection() {
        const paths = []
        for (let i = 0; i < ledgeModel.count; i++) {
            if (ledgeModel.get(i).selected)
                paths.push(ledgeModel.get(i).path)
        }
        root.selectedPathList = paths
        root.selectionCount = paths.length
        if (paths.length === 0)
            root.selectionAnchor = -1
        root.syncPinnedCount()
    }

    function syncPinnedCount() {
        let n = 0
        for (let i = 0; i < ledgeModel.count; i++) {
            if (ledgeModel.get(i).pinned === true)
                n++
        }
        root.pinnedCount = n
    }

    function compactPinned() {
        let insertAt = 0
        let moved = false
        for (let i = 0; i < ledgeModel.count; i++) {
            if (ledgeModel.get(i).pinned === true) {
                if (i !== insertAt) {
                    ledgeModel.move(i, insertAt, 1)
                    moved = true
                }
                insertAt++
            }
        }
        if (moved)
            root.selectionAnchor = -1
        syncSelection()
    }

    function toggleSelection(index) {
        if (index < 0 || index >= ledgeModel.count)
            return
        ledgeModel.setProperty(index, "selected", !ledgeModel.get(index).selected)
        root.selectionAnchor = index
        syncSelection()
    }

    function selectRangeTo(index, additive) {
        if (index < 0 || index >= ledgeModel.count)
            return
        if (root.selectionAnchor === -1)
            root.selectionAnchor = index
        const first = Math.min(root.selectionAnchor, index)
        const last = Math.max(root.selectionAnchor, index)
        for (let i = 0; i < ledgeModel.count; i++) {
            const inRange = i >= first && i <= last
            if (inRange !== (ledgeModel.get(i).selected === true)) {
                if (inRange || !additive)
                    ledgeModel.setProperty(i, "selected", inRange)
            }
        }
        syncSelection()
    }

    function clearSelection() {
        for (let i = 0; i < ledgeModel.count; i++) {
            if (ledgeModel.get(i).selected)
                ledgeModel.setProperty(i, "selected", false)
        }
        syncSelection()
    }

    function removeSelected() {
        for (let i = ledgeModel.count - 1; i >= 0; i--) {
            if (ledgeModel.get(i).selected)
                ledgeModel.remove(i)
        }
        syncSelection()
        persist()
    }

    function setPinnedAt(index, pinned) {
        if (index < 0 || index >= ledgeModel.count)
            return
        if ((ledgeModel.get(index).pinned === true) === pinned)
            return
        ledgeModel.setProperty(index, "pinned", pinned)
        compactPinned()
        persist()
        showToast(pinned ? "Pinned - kept on clear" : "Unpinned")
    }

    function targetPaths() {
        return root.selectionCount > 0 ? root.selectedPathList : root.allPaths()
    }

    function indexOfPath(path) {
        for (let i = 0; i < ledgeModel.count; i++) {
            if (ledgeModel.get(i).path === path)
                return i
        }
        return -1
    }

    function addPaths(entries) {
        if (!entries || !entries.length)
            return 0
        const items = Model.itemsFromDrop(entries, Date.now())
        let added = 0
        for (const item of items) {
            if (indexOfPath(item.path) !== -1)
                continue
            ledgeModel.append(Object.assign({ selected: false, pinned: false }, item))
            added++
        }
        if (added > 0) {
            persist()
            showToast(added === 1 ? "Added 1 file" : "Added " + added + " files")
        } else if (items.length > 0) {
            showToast("Already on the ledge")
        }
        return added
    }

    function removePaths(paths) {
        for (const path of paths) {
            const index = indexOfPath(path)
            if (index !== -1)
                ledgeModel.remove(index)
        }
        root.selectionAnchor = -1
        syncSelection()
        persist()
    }

    function removeAt(index) {
        if (index < 0 || index >= ledgeModel.count)
            return
        ledgeModel.remove(index)
        root.selectionAnchor = -1
        syncSelection()
        persist()
    }

    function allPaths() {
        const paths = []
        for (let i = 0; i < ledgeModel.count; i++)
            paths.push(ledgeModel.get(i).path)
        return paths
    }

    function clearLedge() {
        if (ledgeModel.count === 0)
            return
        let removed = 0
        for (let i = ledgeModel.count - 1; i >= 0; i--) {
            if (ledgeModel.get(i).pinned !== true) {
                ledgeModel.remove(i)
                removed++
            }
        }
        if (removed === 0) {
            showToast(ledgeModel.count === 1 ? "Pinned file kept" : "Pinned files kept")
            return
        }
        syncSelection()
        persist()
        showToast(ledgeModel.count > 0 ? "Cleared - pinned files kept" : "Ledge cleared")
    }

    function copyAsFiles(paths) {
        if (!paths.length)
            return
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy --type text/uri-list', "omarchy-ledge", Model.uriList(paths)])
        showToast(paths.length === 1 ? "File copied" : paths.length + " files copied")
    }

    function copyPath(path) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "omarchy-ledge", path])
        showToast("Path copied")
    }

    function openPath(path) {
        Quickshell.execDetached(["xdg-open", path])
    }

    function showToast(text) {
        root.toast = text
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 2200
        onTriggered: root.toast = ""
    }

    function persist() {
        if (!root.statePath)
            return
        const items = []
        for (let i = 0; i < ledgeModel.count; i++) {
            const entry = ledgeModel.get(i)
            items.push({
                path: entry.path,
                addedAt: entry.addedAt,
                pinned: entry.pinned === true
            })
        }
        stateFile.setText(Model.serialize(items))
    }

    function restore(text) {
        const items = Model.deserialize(text)
        if (!items.length)
            return
        const raced = ledgeModel.count > 0
        for (const item of items) {
            const index = indexOfPath(item.path)
            if (index === -1) {
                ledgeModel.append(Object.assign({ selected: false, pinned: false }, item))
            } else if (item.pinned === true && ledgeModel.get(index).pinned !== true) {
                ledgeModel.setProperty(index, "pinned", true)
            }
        }
        compactPinned()
        if (raced)
            persist()
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        printErrors: false
        onLoaded: root.restore(stateFile.text())
        onLoadFailed: error => {}
    }

    Component.onCompleted: {
        const dir = Model.stateDir(root.homeDir, root.stateHomeDir)
        if (dir)
            Quickshell.execDetached(["mkdir", "-p", dir])
    }

    // --- IPC Handler ---
    function entriesFromArgument(argument) {
        const text = String(argument)
        let entries = null
        try {
            const parsed = JSON.parse(text)
            if (Array.isArray(parsed))
                entries = parsed
            else if (parsed && Array.isArray(parsed.paths))
                entries = parsed.paths
        } catch (e) {}
        return entries ? entries : text.split("\n")
    }

    IpcHandler {
        target: "bylund.ledge"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.toggle() }

        function add(paths: string): string {
            const added = root.addPaths(root.entriesFromArgument(paths))
            root.open()
            return String(added)
        }

        function addQuiet(paths: string): string {
            return String(root.addPaths(root.entriesFromArgument(paths)))
        }

        function list(): string { return root.allPaths().join("\n") }
        function count(): string { return String(ledgeModel.count) }
        function clear(): string { root.clearLedge(); return String(ledgeModel.count) }
        function pin(paths: string): string {
            const n = root.addPaths(root.entriesFromArgument(paths))
            root.open()
            return String(n)
        }
        function unpin(paths: string): string {
            return "0"
        }
    }

    LedgeTheme {
        id: ledgeTheme
    }

    // --- Bar Button ---
    Item {
        id: barButton
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: ledgeModel.count > 0 ? contentRow.implicitWidth + 14 : 26
        implicitHeight: 36

        Rectangle {
            anchors.centerIn: parent
            width: parent.implicitWidth
            height: 26
            radius: 6
            color: mouseArea.containsMouse || root.opened || root.barDropActive
                   ? Theme.popupSurfaceSelected
                   : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.barDropActive ? root.glyphDrop : root.glyphLedge
                    color: root.barDropActive || root.opened
                           ? Theme.primary
                           : (mouseArea.containsMouse ? Theme.colOnSurface : (ledgeModel.count > 0 ? Theme.primary : Theme.colOnSurfaceVariant))
                    font.family: root.fontFamily
                    font.pixelSize: 15

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                Text {
                    id: countLabel
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ledgeModel.count > 0
                    text: ledgeModel.count
                    color: mouseArea.containsMouse ? Theme.colOnSurface : Theme.colOnSurfaceVariant
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.copyAsFiles(root.allPaths())
                    root.open()
                } else {
                    root.toggle()
                }
            }
        }

        DropArea {
            anchors.fill: parent
            onEntered: drag => {
                if (drag.hasUrls || drag.hasText) {
                    drag.accept(Qt.CopyAction)
                    root.barDropActive = true
                    springTimer.restart()
                }
            }
            onExited: {
                root.barDropActive = false
                springTimer.stop()
            }
            onDropped: drop => {
                root.barDropActive = false
                springTimer.stop()
                const entries = drop.hasUrls ? drop.urls : String(drop.text).split("\n")
                if (root.addPaths(entries) > 0 || drop.hasUrls)
                    drop.accept(Qt.CopyAction)
            }
        }

        Timer {
            id: springTimer
            interval: 700
            onTriggered: if (root.barDropActive) root.open()
        }
    }

    // --- Floating Popup ---
    LedgePopup {
        id: popup
        anchorItem: barButton
        open: false
        cardWidth: 340
        cardHeight: popup.fittedHeight(body.implicitHeight, 520)
        focusTarget: body
        onCloseRequested: root.close()

        Item {
            id: body
            anchors.fill: parent
            focus: true
            implicitHeight: header.height + 12 + (root.settingsOpen ? settingsView.implicitHeight : Math.max(120, ledgeModel.count * 64))

            Keys.onEscapePressed: root.close()

            // Header
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                z: 2

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyphLedge + "  Ledge"
                    color: ledgeTheme.text
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 8
                        text: root.settingsOpen
                              ? "Settings"
                              : (root.selectionCount > 0
                                 ? root.selectionCount + " selected"
                                 : (ledgeModel.count === 1 ? "1 file" : ledgeModel.count + " files"))
                        color: root.selectionCount > 0 ? ledgeTheme.accent : ledgeTheme.muted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }

                    LedgeIconButton {
                        theme: ledgeTheme
                        icon: root.glyphCopyAll
                        tooltip: root.selectionCount > 0 ? "Copy selected" : "Copy all"
                        tooltipEdge: "bottom"
                        visible: ledgeModel.count > 0 && !root.settingsOpen
                        onClicked: root.copyAsFiles(root.targetPaths())
                    }

                    LedgeIconButton {
                        theme: ledgeTheme
                        icon: root.glyphTrash
                        tooltip: root.selectionCount > 0 ? "Remove selected" : (root.pinnedCount > 0 ? "Clear unpinned" : "Clear ledge")
                        tooltipEdge: "bottom"
                        danger: true
                        visible: !root.settingsOpen && (root.selectionCount > 0 || root.pinnedCount < ledgeModel.count)
                        onClicked: root.selectionCount > 0 ? root.removeSelected() : root.clearLedge()
                    }

                    LedgeIconButton {
                        theme: ledgeTheme
                        icon: root.glyphClose
                        tooltip: "Close"
                        tooltipEdge: "bottom"
                        onClicked: root.close()
                    }
                }
            }

            // File List
            ListView {
                id: list
                anchors.top: header.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                spacing: 6
                model: ledgeModel
                visible: ledgeModel.count > 0 && !root.settingsOpen
                boundsBehavior: Flickable.StopAtBounds

                delegate: LedgeChip {
                    id: chipDelegate
                    required property int index
                    required property var model

                    width: ListView.view.width
                    theme: ledgeTheme
                    fontFamily: root.fontFamily
                    allowMove: root.moveAllowed
                    path: model.path
                    fileName: model.fileName
                    ext: model.ext
                    icon: model.icon
                    isImage: model.isImage
                    selected: model.selected === true
                    pinned: model.pinned === true
                    selectionCount: root.selectionCount
                    dragPaths: model.selected === true ? root.selectedPathList : [chipDelegate.path]

                    onCopyFileRequested: {
                        root.clearSelection()
                        root.copyAsFiles([chipDelegate.path])
                    }
                    onCopyPathRequested: root.copyPath(chipDelegate.path)
                    onOpenRequested: root.openPath(chipDelegate.path)
                    onRemoveRequested: root.removeAt(chipDelegate.index)
                    onPinRequested: root.setPinnedAt(chipDelegate.index, !chipDelegate.pinned)
                    onSelectToggleRequested: root.toggleSelection(chipDelegate.index)
                    onSelectRangeRequested: additive => root.selectRangeTo(chipDelegate.index, additive)
                    onDragStarted: {
                        root.toast = ""
                        root.dragOutActive = true
                    }
                    onDragFinished: {
                        root.dragOutActive = false
                        if (chipDelegate.selected)
                            root.clearSelection()
                    }
                }
            }

            // Empty State
            Rectangle {
                anchors.top: header.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: ledgeModel.count === 0 && !root.settingsOpen
                radius: ledgeTheme.radius
                color: root.dropActive ? ledgeTheme.accentSoft : "transparent"
                border.width: 1
                border.color: ledgeTheme.border

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 24

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.glyphDrop
                        font.family: root.fontFamily
                        font.pixelSize: 24
                        color: ledgeTheme.muted
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Drop files here"
                        color: ledgeTheme.text
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Or drop directly on the bar icon"
                        color: ledgeTheme.muted
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            // Drop Target for popup card
            DropArea {
                anchors.fill: parent
                onEntered: drag => {
                    if (drag.hasUrls || drag.hasText) {
                        drag.accept(Qt.CopyAction)
                        root.dropActive = true
                    }
                }
                onExited: root.dropActive = false
                onDropped: drop => {
                    root.dropActive = false
                    const entries = drop.hasUrls ? drop.urls : String(drop.text).split("\n")
                    if (root.addPaths(entries) > 0 || drop.hasUrls)
                        drop.accept(Qt.CopyAction)
                }
            }

            // Toast Message
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: Math.min(parent.width - 16, toastLabel.implicitWidth + 20)
                height: toastLabel.implicitHeight + 10
                radius: height / 2
                color: ledgeTheme.accent
                opacity: root.toast ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                Text {
                    id: toastLabel
                    anchors.centerIn: parent
                    text: root.toast
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - 24)
                    color: Theme.colOnPrimary
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
