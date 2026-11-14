import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

Item {
    id: root
    implicitHeight: 40

    Rectangle {
        id: uptimePill
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        implicitWidth: uptimeRow.implicitWidth + 24
        radius: height / 2
        color: Theme.colLayer1
        border.width: 1
        border.color: Theme.colLayer1Border

        RowLayout {
            id: uptimeRow
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                text: "schedule"
                iconSize: 20
                color: Theme.colOnLayer0
            }
            StyledText {
                text: "Up " + DateTime.uptime
                font.pixelSize: Theme.font.pixelSize.small
                color: Theme.colOnLayer0
            }
        }
    }

    ButtonGroup {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        color: Theme.colLayer1
        padding: 4

        RippleButton {
            Layout.fillHeight: true
            implicitWidth: 32
            buttonRadius: Theme.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Theme.colLayer1Hover
            colRipple: Theme.colLayer1Active
            onClicked: {
                Quickshell.execDetached(["hyprctl", "reload"]);
                Quickshell.reload(true);
            }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "restart_alt"
                iconSize: 20
                color: Theme.colOnLayer0
            }
        }

        RippleButton {
            Layout.fillHeight: true
            implicitWidth: 32
            buttonRadius: Theme.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Theme.colLayer1Hover
            colRipple: Theme.colLayer1Active
            onClicked: GlobalStates.sessionOpen = true
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "power_settings_new"
                iconSize: 20
                color: Theme.colOnLayer0
            }
        }
    }
}
