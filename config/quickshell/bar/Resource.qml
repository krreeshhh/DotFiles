import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Item {
    id: root
    property string iconName: "memory"
    property real percentage: 0
    property bool shown: true
    property real warningThreshold: 85

    visible: shown
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.sizes.barHeight

    readonly property bool warning: percentage * 100 >= warningThreshold

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 3

        MaterialSymbol {
            text: root.iconName
            iconSize: 16
            color: root.warning ? Theme.colorError : Theme.colOnLayer1
        }
        StyledText {
            text: Math.round(root.percentage * 100) + "%"
            font.pixelSize: Theme.font.pixelSize.smaller
            color: root.warning ? Theme.colorError : Theme.colOnLayer1
        }
    }
}
