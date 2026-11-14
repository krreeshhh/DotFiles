import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Item {
    id: root
    signal activated()

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Theme.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Theme.font.pixelSize.large
            color: Theme.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            font.pixelSize: Theme.font.pixelSize.small
            color: Theme.colSubtext
            text: "•"
        }

        StyledText {
            font.pixelSize: Theme.font.pixelSize.small
            color: Theme.colOnLayer1
            text: DateTime.longDate
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
