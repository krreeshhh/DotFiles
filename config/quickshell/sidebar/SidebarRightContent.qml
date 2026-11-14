import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        SystemButtonRow {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.topMargin: 4
        }

        QuickSliders {
            Layout.fillWidth: true
            Layout.fillHeight: false
        }

        QuickToggleGrid {
            Layout.fillWidth: true
            Layout.fillHeight: false
        }

        CenterArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        BottomWidgetGroup {
            Layout.fillWidth: true
            Layout.fillHeight: false
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen)
                Notifications.markAllRead();
        }
    }
}
