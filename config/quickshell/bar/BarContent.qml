import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"
import "../lib"
import "../ledge"

Item {
    id: root

    signal toggleQuickSettings()
    signal toggleWifi()
    signal toggleBluetooth()
    signal toggleSession()

    readonly property var screen: root.QsWindow.window?.screen
    readonly property int useShortenedForm: screen && screen.width < 1200 ? 1 : 0
    readonly property int centerSideModuleWidth: useShortenedForm === 1
        ? Theme.sizes.barCenterSideModuleWidthShortened
        : Theme.sizes.barCenterSideModuleWidth

    implicitHeight: Theme.sizes.barHeight

    // ------------------------------------------------------------------
    // Left zone: launcher + active window (scroll = brightness)
    // ------------------------------------------------------------------
    MouseArea {
        id: leftZone
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            right: middleSection.left
        }
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) Brightness.increaseBrightness();
            else Brightness.decreaseBrightness();
        }
        onClicked: root.toggleQuickSettings()

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.rounding.screen
                rightMargin: Theme.rounding.screen
            }
            spacing: 6

            RippleButton {
                id: launcherButton
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer1Hover
                colRipple: Theme.colLayer1Active
                downAction: () => Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "shell", "toggleAppLauncher"])

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "apps"
                    iconSize: 20
                    color: Theme.colOnSurface
                }
            }

            ActiveWindow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.useShortenedForm === 0
            }
        }
    }

    // ------------------------------------------------------------------
    // Centre zone: resources/media | workspaces | clock/utils/battery
    // ------------------------------------------------------------------
    Row {
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        BarGroup {
            id: leftCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth

            Resources { Layout.fillWidth: true }
            Media {
                visible: root.useShortenedForm === 0
                Layout.fillWidth: true
            }
        }

        BarGroup {
            id: middleCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            padding: 0
            implicitWidth: workspacesWidget.implicitWidth

            Workspaces {
                id: workspacesWidget
                Layout.fillHeight: true
            }
        }

        MouseArea {
            id: rightCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth
            implicitHeight: rightCenterGroupContent.implicitHeight
            onClicked: root.toggleQuickSettings()

            BarGroup {
                id: rightCenterGroupContent
                anchors.fill: parent

                ClockWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    onActivated: root.toggleQuickSettings()
                }

                UtilButtons {
                    visible: root.useShortenedForm === 0
                    Layout.alignment: Qt.AlignVCenter
                }

                BatteryIndicator {
                    visible: root.useShortenedForm === 0 && Battery.available
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Right zone: indicators pill, tray, ledge (scroll = volume)
    // ------------------------------------------------------------------
    MouseArea {
        id: rightZone
        anchors {
            left: middleSection.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) Audio.incrementVolume();
            else Audio.decrementVolume();
        }
        onClicked: root.toggleQuickSettings()

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 4
                rightMargin: Theme.rounding.screen
            }
            spacing: 6
            layoutDirection: Qt.RightToLeft

            // Indicator pill
            RippleButton {
                id: indicatorPill
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: indicatorsRow.implicitWidth + 16
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer1Hover
                colRipple: Theme.colLayer1Active
                colBackgroundToggled: Theme.colSecondaryContainer
                toggled: GlobalStates.sidebarRightOpen
                downAction: () => root.toggleQuickSettings()

                property color colText: toggled ? Theme.colOnSecondaryContainer : Theme.colOnLayer0

                RowLayout {
                    id: indicatorsRow
                    anchors.centerIn: parent
                    spacing: 7

                    Revealer {
                        reveal: Audio.muted
                        Layout.fillHeight: true
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: 18
                            color: indicatorPill.colText
                        }
                    }
                    Revealer {
                        reveal: Audio.micMuted
                        Layout.fillHeight: true
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: 18
                            color: indicatorPill.colText
                        }
                    }
                    MaterialSymbol {
                        text: Network.materialSymbol
                        iconSize: 18
                        color: indicatorPill.colText
                    }
                    MaterialSymbol {
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected"
                            : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: 18
                        color: indicatorPill.colText
                    }
                    Item {
                        Layout.preferredWidth: badge.implicitWidth
                        Layout.preferredHeight: badge.implicitHeight
                        visible: Notifications.unread > 0
                        Rectangle {
                            id: badge
                            implicitWidth: Math.max(16, countText.implicitWidth + 8)
                            implicitHeight: 16
                            radius: 8
                            color: Theme.primary
                            StyledText {
                                id: countText
                                anchors.centerIn: parent
                                text: Math.min(Notifications.unread, 99)
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.onPrimary
                            }
                        }
                    }
                }
            }

            TrayDrawer {
                Layout.fillHeight: true
            }

            LedgeWidget {
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
