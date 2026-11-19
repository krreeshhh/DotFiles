import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
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
    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus();
            root.selectedIndex = 0;
        }
    }

    function openMenu() {
        closeTimer.stop();
        root.selectedIndex = 0;
        root.visible = true;
        root.shown = true;
        keyHandler.forceActiveFocus();
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
        interval: 180
        repeat: false
        onTriggered: {
            if (!root.shown) {
                root.visible = false;
            }
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

    // Centered Card UI
    Rectangle {
        id: card
        width: 560
        height: 388
        anchors.centerIn: parent
        radius: 14
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1.5

        opacity: root.shown ? 1.0 : 0.0
        transform: [
            Translate {
                id: cardTrans
                y: root.shown ? 0 : -20
                Behavior on y {
                    NumberAnimation {
                        duration: root.shown ? 240 : 160
                        easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
                    }
                }
            }
        ]

        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? 180 : 130
                easing.type: root.shown ? Easing.OutCubic : Easing.InQuad
            }
        }

        // Prevent clicks inside card from dismissing
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onUpPressed: (event) => {
                if (root.selectedIndex > 0) root.selectedIndex--;
                else root.selectedIndex = sessionItems.length - 1;
                event.accepted = true;
            }

            Keys.onDownPressed: (event) => {
                if (root.selectedIndex < sessionItems.length - 1) root.selectedIndex++;
                else root.selectedIndex = 0;
                event.accepted = true;
            }

            Keys.onReturnPressed: (event) => {
                executeItem(sessionItems[root.selectedIndex]);
                event.accepted = true;
            }

            Keys.onEnterPressed: (event) => {
                executeItem(sessionItems[root.selectedIndex]);
                event.accepted = true;
            }

            Keys.onEscapePressed: (event) => {
                root.closeMenu();
                event.accepted = true;
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_1) {
                    executeItem(sessionItems[0]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_2) {
                    executeItem(sessionItems[1]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_3) {
                    executeItem(sessionItems[2]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_4) {
                    executeItem(sessionItems[3]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_5) {
                    executeItem(sessionItems[4]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_L) {
                    executeItem(sessionItems[0]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_O) {
                    executeItem(sessionItems[1]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_S) {
                    executeItem(sessionItems[2]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    executeItem(sessionItems[3]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_P) {
                    executeItem(sessionItems[4]);
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    spacing: 10

                    Text {
                        text: "󰐥"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Session Manager"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.colOnSurface
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "1-5 or Arrows • Enter • Esc"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.colOnSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.outline
                    opacity: 0.6
                }

                // Options List
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    interactive: false

                    model: sessionItems

                    delegate: Rectangle {
                        id: rowDelegate
                        width: listView.width
                        height: 52
                        radius: 8

                        property bool isSelected: index === root.selectedIndex
                        property bool isDanger: modelData.isDanger === true

                        color: isSelected
                               ? (isDanger ? Qt.rgba(Theme.colorError.r, Theme.colorError.g, Theme.colorError.b, 0.22) : Theme.popupSurfaceSelected)
                               : (rowMouse.containsMouse ? Theme.popupSurfaceVariant : "transparent")

                        border.width: isSelected ? 1 : 0
                        border.color: isDanger ? Theme.colorError : Theme.primary

                        Behavior on color {
                            ColorAnimation { duration: 80 }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 14

                            // Action Icon
                            Text {
                                text: modelData.icon
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                color: rowDelegate.isDanger
                                       ? Theme.colorError
                                       : (rowDelegate.isSelected ? Theme.primary : Theme.colOnSurface)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Title & Description Column
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: rowDelegate.isSelected
                                           ? (rowDelegate.isDanger ? Theme.colorError : Theme.primary)
                                           : Theme.colOnSurface
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.desc
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.colOnSurfaceVariant
                                    opacity: 0.9
                                    Layout.fillWidth: true
                                }
                            }

                            // Keyboard Shortcut Indicator
                            Text {
                                text: modelData.shortcut
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: rowDelegate.isSelected
                                       ? (rowDelegate.isDanger ? Theme.colorError : Theme.primary)
                                       : Theme.colOnSurfaceVariant
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.selectedIndex = index;
                            }
                            onClicked: {
                                executeItem(modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var sessionItems: [
        {
            action: "lock",
            name: "Lock Screen",
            desc: "Secure the session and turn off screen",
            icon: "󰌾",
            shortcut: "1",
            cmd: [(Quickshell.env ? Quickshell.env("HOME") : "") + "/.config/hypr/scripts/lock.sh"],
            isDanger: false
        },
        {
            action: "logout",
            name: "Log Out",
            desc: "Exit Hyprland and return to display manager",
            icon: "󰍃",
            shortcut: "2",
            cmd: [(Quickshell.env ? Quickshell.env("HOME") : "") + "/.config/hypr/scripts/logout.sh"],
            isDanger: false
        },
        {
            action: "suspend",
            name: "Suspend",
            desc: "Put the system into low-power sleep mode",
            icon: "󰒲",
            shortcut: "3",
            cmd: [(Quickshell.env ? Quickshell.env("HOME") : "") + "/.config/hypr/scripts/suspend.sh"],
            isDanger: false
        },
        {
            action: "reboot",
            name: "Restart System",
            desc: "Reboot hardware immediately",
            icon: "󰜉",
            shortcut: "4",
            cmd: ["systemctl", "reboot"],
            isDanger: false
        },
        {
            action: "shutdown",
            name: "Shut Down",
            desc: "Power off computer completely",
            icon: "󰐥",
            shortcut: "5",
            cmd: ["systemctl", "poweroff"],
            isDanger: true
        }
    ]

    function executeItem(item) {
        if (!item || !item.cmd) return;
        root.closeImmediate();
        Quickshell.execDetached(item.cmd);
    }
}
