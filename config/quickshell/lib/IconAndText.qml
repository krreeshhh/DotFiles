import ".."
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property alias icon: iconWidget.text
    property alias text: label.text
    property alias iconSize: iconWidget.iconSize
    property alias font: label.font
    property alias color: label.color
    property alias iconColor: iconWidget.color
    property real spacing: 6

    MaterialSymbol {
        id: iconWidget
        color: Theme.colOnSurface
        iconSize: 18
    }
    StyledText {
        id: label
        Layout.fillWidth: true
        color: Theme.colOnSurface
    }
}
