import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Rectangle {
    id: root
    radius: Theme.rounding.normal
    color: Theme.colLayer1
    border.width: 1
    border.color: Theme.colLayer1Border
    clip: true

    property int tab: 0 // 0 = notifications, 1 = calendar

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                toggled: root.tab === 0
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer2Hover
                colBackgroundToggled: Theme.colSecondaryContainer
                colRipple: Theme.colLayer1Active
                colRippleToggled: Theme.alpha(Theme.colSecondaryContainer, 0.7)
                onClicked: root.tab = 0
                contentItem: StyledText {
                    text: "Notifications" + (Notifications.unread > 0 ? " (" + Notifications.unread + ")" : "")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.font.pixelSize.small
                    color: root.tab === 0 ? Theme.colOnSecondaryContainer : Theme.colOnLayer1
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                toggled: root.tab === 1
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer2Hover
                colBackgroundToggled: Theme.colSecondaryContainer
                colRipple: Theme.colLayer1Active
                colRippleToggled: Theme.alpha(Theme.colSecondaryContainer, 0.7)
                onClicked: root.tab = 1
                contentItem: StyledText {
                    text: "Calendar"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.font.pixelSize.small
                    color: root.tab === 1 ? Theme.colOnSecondaryContainer : Theme.colOnLayer1
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tab

            NotificationList {}

            CalendarWidget {}
        }
    }
}
