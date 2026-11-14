import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

Item {
    id: root
    readonly property bool isCharging: Battery.isCharging
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= 0.15

    implicitWidth: batteryProgress.implicitWidth
    implicitHeight: Theme.sizes.barHeight

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        value: root.percentage
        valueBarWidth: 32
        valueBarHeight: 18
        highlightColor: (root.isLow && !root.isCharging) ? Theme.colorError : Theme.colOnSecondaryContainer

        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            RowLayout {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: (parent.height - height) / 2
                }
                spacing: 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Theme.font.pixelSize.smaller
                    visible: root.isCharging && root.percentage < 1
                }
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "shell", "toggleControlCenter"])
    }
}
