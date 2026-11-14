import ".."
import QtQuick
import QtQuick.Layouts

ToolbarButton {
    id: iconBtn
    implicitWidth: height

    colBackgroundToggled: Theme.colSecondaryContainer
    colBackgroundToggledHover: Theme.alpha(Theme.colSecondaryContainer, 0.85)
    colRippleToggled: Theme.alpha(Theme.colSecondaryContainer, 0.7)
    property color colText: toggled ? Theme.colOnSecondaryContainer : Theme.colOnSurfaceVariant

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        iconSize: 22
        text: iconBtn.text
        color: iconBtn.colText
        animateChange: true
    }
}
