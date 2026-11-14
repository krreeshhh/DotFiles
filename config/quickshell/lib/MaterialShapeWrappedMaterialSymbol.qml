import ".."
import QtQuick

Rectangle {
    id: root
    property alias text: symbol.text
    property alias iconSize: symbol.iconSize
    property alias font: symbol.font
    property alias colSymbol: symbol.color
    property real padding: 6

    color: Theme.colSecondaryContainer
    colSymbol: Theme.colOnSecondaryContainer
    radius: Theme.rounding.full
    implicitWidth: Math.max(symbol.implicitWidth, symbol.implicitHeight) + padding * 2
    implicitHeight: implicitWidth

    MaterialSymbol {
        id: symbol
        anchors.centerIn: parent
        color: root.colSymbol
    }
}
