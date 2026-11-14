import ".."
import QtQuick

/**
 * Recreation of GTK revealer. Expects one single child.
 */
Item {
    id: root
    property bool reveal
    property bool vertical: false
    clip: true

    implicitWidth: (reveal || vertical) ? childrenRect.width : 0
    implicitHeight: (reveal || !vertical) ? childrenRect.height : 0
    visible: reveal || (implicitWidth > 0 && !vertical) || (implicitHeight > 0 && vertical)

    Behavior on implicitWidth {
        enabled: !vertical
        NumberAnimation { duration: Theme.animation.normal; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        enabled: vertical
        NumberAnimation { duration: Theme.animation.normal; easing.type: Easing.OutCubic }
    }
}
