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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool shown: false
    property string fifoPath: ""
    property string promptText: "Elevated root privileges required for system maintenance."

    function openAuth(fifo, prompt) {
        fifoPath = fifo || "";
        promptText = prompt && prompt.length > 0 ? prompt : "Elevated root privileges required for system maintenance.";
        passwordField.text = "";
        root.visible = true;
        root.shown = true;
        passwordField.forceActiveFocus();
    }

    function closeImmediate() {
        root.shown = false;
        root.visible = false;
        passwordField.text = "";
    }

    function submit() {
        var pwd = passwordField.text;
        var targetFifo = fifoPath;
        closeImmediate();
        if (targetFifo && targetFifo.length > 0) {
            Quickshell.execDetached(["python3", "-c", "import sys; f=open(sys.argv[1], 'w'); f.write(sys.argv[2] + '\\n'); f.flush(); f.close()", targetFifo, pwd]);
        }
    }

    function cancel() {
        var targetFifo = fifoPath;
        closeImmediate();
        if (targetFifo && targetFifo.length > 0) {
            Quickshell.execDetached(["python3", "-c", "import sys; f=open(sys.argv[1], 'w'); f.write('\\n'); f.flush(); f.close()", targetFifo]);
        }
    }

    // Backdrop overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.shown ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Central Dialog Card
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 440
        height: 280
        radius: 20
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1.5

        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from reaching backdrop
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header with Icon & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Theme.popupSurfaceSelected
                    border.color: Theme.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Mechanic Authentication"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.colOnSurface
                    }

                    Text {
                        text: "Root Privileges Required"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.primary
                    }
                }
            }

            // Description / Prompt Reason
            Text {
                Layout.fillWidth: true
                text: root.promptText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.colOnSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // Password Input Box
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 12
                color: Theme.popupSurfaceVariant
                border.color: passwordField.activeFocus ? Theme.primary : Theme.popupBorder
                border.width: passwordField.activeFocus ? 1.5 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "󰌋"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        color: passwordField.activeFocus ? Theme.primary : Theme.colOnSurfaceVariant
                    }

                    TextInput {
                        id: passwordField
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.colOnSurface
                        echoMode: TextInput.Password
                        focus: true
                        selectByMouse: true

                        Keys.onReturnPressed: root.submit()
                        Keys.onEscapePressed: root.cancel()

                        Text {
                            anchors.fill: parent
                            text: "Enter administrator password..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.colOnSurfaceVariant
                            visible: !passwordField.text && !passwordField.activeFocus
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons (Cancel / Authenticate)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Cancel Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
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

                // Authenticate Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
                    color: authMouse.containsMouse ? Qt.darker(Theme.primary, 1.15) : Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "Authenticate"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.colOnPrimary
                    }

                    MouseArea {
                        id: authMouse
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
