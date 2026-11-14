import QtQuick
import QtQuick.Layouts
import ".."
import "../lib"

RippleButton {
    id: root

    property string iconName: ""
    property string label: ""
    property bool active: false
    property int span: 1

    Layout.columnSpan: span
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitHeight: 58
    buttonRadius: Theme.rounding.normal

    toggled: active
    colBackground: Theme.colLayer2
    colBackgroundHover: Theme.colLayer2Hover
    colBackgroundToggled: Theme.colPrimaryContainer
    colBackgroundToggledHover: Theme.alpha(Theme.colPrimaryContainer, 0.85)
    colRipple: Theme.colLayer2Active
    colRippleToggled: Theme.alpha(Theme.colPrimaryContainer, 0.7)

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                text: root.iconName
                fill: root.active ? 1 : 0
                iconSize: 22
                color: root.active ? Theme.colOnPrimaryContainer : Theme.colOnLayer2
            }

            StyledText {
                text: root.label
                font.pixelSize: Theme.font.pixelSize.small
                font.weight: Font.Medium
                color: root.active ? Theme.colOnPrimaryContainer : Theme.colOnLayer2
                visible: text.length > 0
            }
        }
    }
}
