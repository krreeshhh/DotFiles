import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."

RowLayout {
    id: root
    spacing: 4

    property bool expanded: true
    property var activeMenuHandle: null
    property Item activeTrayItem: null

    // Toggle Button
    Item {
        id: toggleBtn
        Layout.preferredWidth: 22
        Layout.preferredHeight: 36

        Text {
            anchors.centerIn: parent
            text: "󱊖"
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: toggleMouse.containsMouse ? Theme.primary : Theme.colOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.expanded = !root.expanded;
            }
        }
    }

    // Tray Icons Container with smooth collapse
    Item {
        id: trayContainer
        clip: true
        Layout.preferredWidth: root.expanded ? trayRow.implicitWidth : 0
        Layout.preferredHeight: 36

        Behavior on Layout.preferredWidth {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Row {
            id: trayRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: SystemTray.items.values

                delegate: Item {
                    id: trayItem
                    width: 22
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        width: 15
                        height: 15
                        anchors.centerIn: parent
                        source: modelData.icon
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                modelData.activate();
                            } else if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu && modelData.menu) {
                                    root.activeTrayItem = trayItem;
                                    root.activeMenuHandle = modelData.menu;
                                    trayPopup.visible = true;
                                } else {
                                    modelData.secondaryActivate();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Material You Context Menu Popup
    PopupWindow {
        id: trayPopup
        visible: false

        anchor {
            window: root.activeTrayItem ? root.activeTrayItem.QsWindow.window : null
            adjustment: PopupAdjustment.None
            gravity: Edges.Bottom | Edges.Right
            onAnchoring: {
                if (!root.activeTrayItem) return;
                const pos = root.activeTrayItem.QsWindow.contentItem.mapFromItem(
                    root.activeTrayItem,
                    root.activeTrayItem.width / 2 - trayPopup.implicitWidth / 2,
                    root.activeTrayItem.height + 6
                );
                anchor.rect.x = pos.x;
                anchor.rect.y = pos.y;
            }
        }

        implicitWidth: Math.max(160, menuContentCol.implicitWidth + 24)
        implicitHeight: menuContentCol.implicitHeight + 16
        color: "transparent"

        QsMenuOpener {
            id: menuOpener
            menu: root.activeMenuHandle
        }

        Timer {
            id: autoCloseTimer
            interval: 5000
            repeat: false
            onTriggered: {
                trayPopup.visible = false;
            }
        }

        onVisibleChanged: {
            if (visible) {
                popupBg.forceActiveFocus();
                autoCloseTimer.restart();
            } else {
                autoCloseTimer.stop();
            }
        }

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 12
            color: Theme.popupSurface
            border.color: Theme.popupBorder
            border.width: 1
            focus: true

            Keys.onEscapePressed: {
                trayPopup.visible = false;
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        autoCloseTimer.stop();
                    } else {
                        autoCloseTimer.restart();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: autoCloseTimer.stop()
                onExited: autoCloseTimer.restart()
            }

            ColumnLayout {
                id: menuContentCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        id: menuItem
                        Layout.fillWidth: true
                        Layout.preferredHeight: modelData.isSeparator ? 7 : 28

                        // Separator
                        Rectangle {
                            visible: modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 8
                            height: 1
                            color: Theme.popupBorder
                        }

                        // Menu Action Entry
                        Rectangle {
                            visible: !modelData.isSeparator
                            anchors.fill: parent
                            radius: 6
                            color: itemMouse.containsMouse ? Theme.popupSurfaceSelected : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    visible: modelData.checkState === Qt.Checked || (modelData.icon && modelData.icon.length > 0)
                                    text: modelData.checkState === Qt.Checked ? "󰄬" : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.primary
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: !modelData.enabled ? Theme.colOnSurfaceVariant : (itemMouse.containsMouse ? Theme.primary : Theme.colOnSurface)
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: modelData.enabled
                                onClicked: {
                                    modelData.triggered();
                                    trayPopup.visible = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
