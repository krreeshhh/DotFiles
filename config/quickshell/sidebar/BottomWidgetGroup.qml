import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

RowLayout {
    id: root
    spacing: 6

    RippleButton {
        Layout.fillWidth: true
        implicitHeight: 38
        buttonRadius: Theme.rounding.full
        colBackground: Theme.colLayer1
        colBackgroundHover: Theme.colLayer2Hover
        colRipple: Theme.colLayer1Active
        onClicked: Notifications.dismissAll()
        contentItem: RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: "delete_sweep"
                iconSize: 18
                color: Theme.colOnLayer1
            }
            StyledText {
                text: "Clear"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
        }
    }

    RippleButton {
        Layout.fillWidth: true
        implicitHeight: 38
        buttonRadius: Theme.rounding.full
        colBackground: Theme.colLayer1
        colBackgroundHover: Theme.colLayer2Hover
        colRipple: Theme.colLayer1Active
        onClicked: Session.lock()
        contentItem: RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: "lock"
                iconSize: 18
                color: Theme.colOnLayer1
            }
            StyledText {
                text: "Lock"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
        }
    }

    RippleButton {
        Layout.fillWidth: true
        implicitHeight: 38
        buttonRadius: Theme.rounding.full
        colBackground: Theme.colLayer1
        colBackgroundHover: Theme.colLayer2Hover
        colRipple: Theme.colLayer1Active
        toggled: GlobalStates.sessionOpen
        colBackgroundToggled: Theme.colPrimaryContainer
        colRippleToggled: Theme.alpha(Theme.colPrimaryContainer, 0.7)
        onClicked: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
        contentItem: RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: "power_settings_new"
                iconSize: 18
                color: GlobalStates.sessionOpen ? Theme.colOnPrimaryContainer : Theme.colOnLayer1
            }
            StyledText {
                text: "Session"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: GlobalStates.sessionOpen ? Theme.colOnPrimaryContainer : Theme.colOnLayer1
            }
        }
    }
}
