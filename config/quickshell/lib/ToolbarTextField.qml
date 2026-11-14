import ".."
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

TextField {
    id: filterField

    property alias colBackground: background.color

    Layout.fillHeight: true
    implicitWidth: 200
    padding: 10

    placeholderTextColor: Theme.colSubtext
    color: Theme.colOnLayer1
    font {
        family: Theme.font.family.main
        pixelSize: Theme.font.pixelSize.small
        hintingPreference: Font.PreferFullHinting
        variableAxes: Theme.font.variableAxes.main
    }
    renderType: Text.NativeRendering
    selectedTextColor: Theme.colOnSecondaryContainer
    selectionColor: Theme.colSecondaryContainer

    background: Rectangle {
        id: background
        color: Theme.colLayer1
        radius: Theme.rounding.full
    }
}
