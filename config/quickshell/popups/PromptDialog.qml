import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
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
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool shown: false
    property string fifoPath: ""
    property string dialogTitle: "Input Prompt"
    property string promptText: "Please enter a value:"
    property string placeholderText: "Enter value..."
    property string iconGlyph: "󰍉"

    property var clipboardHistory: []
    property bool showClipboardHistory: false

    Process {
        id: clipseFetchProc
        command: ["python3", "-c", "import json, os; p=os.path.expanduser('~/.config/clipse/clipboard_history.json'); d=json.load(open(p)) if os.path.exists(p) else {}; hist=[x.get('value','').strip() for x in d.get('clipboardHistory',[]) if x.get('value','').strip()][:25]; print(json.dumps(hist))"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line.trim());
                    if (Array.isArray(data)) {
                        root.clipboardHistory = data;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: pasteProc
        command: ["wl-paste", "-n"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line !== undefined && line !== null && line.length > 0) {
                    inputField.text = line;
                    inputField.forceActiveFocus();
                }
            }
        }
    }

    function toggleClipboard() {
        showClipboardHistory = !showClipboardHistory;
        if (showClipboardHistory) {
            clipseFetchProc.running = true;
        }
    }

    function selectClipboardItem(val) {
        inputField.text = val;
        showClipboardHistory = false;
        inputField.forceActiveFocus();
    }

    function openPrompt(fifo, title, prompt, placeholder, defaultValue, icon) {
        fifoPath = fifo || "";
        dialogTitle = title && title.length > 0 ? title : "Input Prompt";
        promptText = prompt && prompt.length > 0 ? prompt : "";
        placeholderText = placeholder && placeholder.length > 0 ? placeholder : "Enter value...";
        iconGlyph = icon && icon.length > 0 ? icon : "󰍉";
        showClipboardHistory = false;
        inputField.text = defaultValue || "";
        root.visible = true;
        root.shown = true;
        clipseFetchProc.running = true;
        inputField.forceActiveFocus();
        if (inputField.text.length > 0) {
            inputField.selectAll();
        }
    }

    function closeImmediate() {
        root.shown = false;
        root.visible = false;
        inputField.text = "";
    }

    function submit() {
        var val = inputField.text.trim();
        var targetFifo = fifoPath;
        closeImmediate();
        if (targetFifo && targetFifo.length > 0) {
            Quickshell.execDetached(["python3", "-c", "import sys; f=open(sys.argv[1], 'w'); f.write(sys.argv[2] + '\\n'); f.flush(); f.close()", targetFifo, val]);
        }
    }

    function cancel() {
        var targetFifo = fifoPath;
        closeImmediate();
        if (targetFifo && targetFifo.length > 0) {
            Quickshell.execDetached(["python3", "-c", "import sys; f=open(sys.argv[1], 'w'); f.write('\\n'); f.flush(); f.close()", targetFifo]);
        }
    }

    // Full screen background dismisser
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.shown ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Main Modal Card
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 520
        height: cardLayout.implicitHeight + 40
        radius: 14
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1.5
        clip: true

        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.94

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }
        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from dismissing through card
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // 1. Header (Icon bubble + Title + Subtitle)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.popupSurfaceSelected
                    border.color: Theme.primary
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: root.iconGlyph
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: root.dialogTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.colOnSurface
                    }

                    Text {
                        visible: root.promptText.length > 0
                        text: root.promptText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.colOnSurfaceVariant
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outlineSubtle
                opacity: 0.6
            }

            // 2. Input Box
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 10
                color: Theme.popupSurfaceVariant
                border.color: inputField.activeFocus ? Theme.primary : Theme.popupBorder
                border.width: inputField.activeFocus ? 1.5 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰄾"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: inputField.activeFocus ? Theme.primary : Theme.colOnSurfaceVariant
                    }

                    TextInput {
                        id: inputField
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.colOnSurface
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.colOnPrimary
                        focus: true
                        selectByMouse: true
                        clip: true

                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: {
                            if (root.showClipboardHistory) {
                                root.showClipboardHistory = false;
                            } else {
                                root.cancel();
                            }
                        }

                        Keys.onPressed: (event) => {
                            if ((event.key === Qt.Key_V && (event.modifiers & Qt.MetaModifier)) ||
                                (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier))) {
                                event.accepted = true;
                                root.toggleClipboard();
                            } else if (event.key === Qt.Key_Down && !root.showClipboardHistory) {
                                event.accepted = true;
                                root.toggleClipboard();
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: root.placeholderText
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.colOnSurfaceVariant
                            visible: !inputField.text && !inputField.inputMethodComposing
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    // Clear button
                    Rectangle {
                        visible: inputField.text.length > 0
                        width: 22
                        height: 22
                        radius: 11
                        color: clearMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.surfaceVariant
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 10
                            color: Theme.colOnSurfaceVariant
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                inputField.text = "";
                                inputField.forceActiveFocus();
                            }
                        }
                    }

                    // Clipboard History / Paste button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: pasteMouse.containsMouse || root.showClipboardHistory ? Theme.popupSurfaceSelected : "transparent"
                        border.color: pasteMouse.containsMouse || root.showClipboardHistory ? Theme.primary : "transparent"
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰅍"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: pasteMouse.containsMouse || root.showClipboardHistory ? Theme.primary : Theme.colOnSurfaceVariant
                        }

                        MouseArea {
                            id: pasteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.toggleClipboard();
                            }
                        }
                    }
                }
            }

            // 2.5 Clipboard History Panel
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.showClipboardHistory
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰅍"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.primary
                    }

                    Text {
                        text: "Clipboard History"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.colOnSurface
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Click or Esc to close"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.colOnSurfaceVariant
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.min(180, Math.max(48, root.clipboardHistory.length * 34 + 8))
                    radius: 8
                    color: Theme.popupSurfaceVariant
                    border.color: Theme.popupBorder
                    border.width: 1
                    clip: true

                    ListView {
                        id: clipList
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2
                        model: root.clipboardHistory
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            anchors.centerIn: parent
                            visible: root.clipboardHistory.length === 0
                            text: "No clipboard history found"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.colOnSurfaceVariant
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: clipList.width
                            height: 32
                            radius: 6
                            color: itemMouse.containsMouse ? Theme.popupSurfaceSelected : "transparent"
                            border.color: itemMouse.containsMouse ? Theme.primary : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: modelData.startsWith("http://") || modelData.startsWith("https://") || modelData.startsWith("git@") ? "" : "󰈙"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: itemMouse.containsMouse ? Theme.primary : Theme.colOnSurfaceVariant
                                }

                                Text {
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.colOnSurface
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectClipboardItem(modelData);
                                }
                            }
                        }
                    }
                }
            }

            // 3. Action Buttons (Cancel / Confirm)
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                // Cancel Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: cancelMouse.containsMouse ? Theme.popupSurfaceSelected : Theme.popupSurfaceVariant
                    border.color: Theme.popupBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.colOnSurface
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cancel()
                    }
                }

                // Submit Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: okMouse.containsMouse ? Qt.darker(Theme.primary, 1.15) : Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "Continue"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.colOnPrimary
                    }

                    MouseArea {
                        id: okMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
