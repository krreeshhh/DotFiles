import QtQuick
import "../Commons"

Rectangle {
    id: surface
    property var borderSpec: null
    property int padding: Style.spacing.popupPadding
    property real contentTopInset: padding
    property real contentBottomInset: padding
    property real contentLeftInset: padding
    property real contentRightInset: padding

    color: Color.popups.background
    border.color: borderSpec && borderSpec.color ? borderSpec.color : Color.popups.border
    border.width: borderSpec && borderSpec.width ? borderSpec.width : 1
    radius: Style.cornerRadius
}
