import ".."
import QtQuick

StyledText {
    id: root
    property real iconSize: Theme.font.pixelSize.small
    property real fill: 0
    property real truncatedFill: Math.round(fill * 10) / 10
    renderType: Text.NativeRendering
    font {
        hintingPreference: Font.PreferNoHinting
        family: Theme.font.family.iconMaterial
        pixelSize: iconSize
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * truncatedFill
        variableAxes: {
            "FILL": truncatedFill,
            "opsz": iconSize
        }
    }

    Behavior on fill {
        NumberAnimation {
            duration: Theme.animation.fast
            easing.type: Easing.OutCubic
        }
    }
}
