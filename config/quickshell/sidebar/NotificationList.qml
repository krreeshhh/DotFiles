import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

Item {
    id: root

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 6
        model: Notifications.list
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: notif
            required property var modelData
            width: listView.width
            implicitHeight: contentColumn.implicitHeight + 20
            radius: Theme.rounding.small
            color: Theme.colLayer2
            border.width: 1
            border.color: Theme.colLayer2Border

            ColumnLayout {
                id: contentColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "notifications"
                        iconSize: 16
                        color: Theme.primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: notif.modelData.appName || "Notification"
                        font.pixelSize: Theme.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Theme.colOnLayer2
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: notif.modelData.time
                            ? Qt.formatDateTime(new Date(notif.modelData.time), "hh:mm") : ""
                        font.pixelSize: Theme.font.pixelSize.smallest
                        color: Theme.colSubtext
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notif.modelData.summary || ""
                    font.pixelSize: Theme.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Theme.colOnLayer2
                    wrapMode: Text.Wrap
                    visible: text.length > 0
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notif.modelData.body || ""
                    font.pixelSize: Theme.font.pixelSize.smaller
                    color: Theme.colOnLayer1
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: (event) => {
                    if (event.button === Qt.MiddleButton) {
                        notif.modelData.dismiss();
                    } else {
                        try { notif.modelData.actions?.[0]?.invoke(); } catch (e) {}
                        notif.modelData.dismiss();
                    }
                }
            }
        }
    }

    // Empty state
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: Notifications.list.length === 0

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "notifications_active"
            iconSize: 42
            color: Theme.alpha(Theme.colOnLayer1, 0.4)
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing here"
            color: Theme.alpha(Theme.colOnLayer1, 0.6)
            font.pixelSize: Theme.font.pixelSize.small
        }
    }
}
