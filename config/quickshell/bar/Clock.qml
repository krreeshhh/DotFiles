import QtQuick
import Quickshell
import ".."

Item {
    id: root
    implicitWidth: clockText.implicitWidth + 12
    implicitHeight: 36

    property var currentTime: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = new Date();
        }
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.currentTime, "hh:mm AP  ddd dd")
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.bold: true
        color: Theme.colOnSurface
    }
}
