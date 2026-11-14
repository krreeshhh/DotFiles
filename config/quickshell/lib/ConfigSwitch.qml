import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 switch with optional icon.
 */
Switch {
    id: root
    property string iconText: ""
    property color colActive: Theme.colPrimary
    property color colInactive: Theme.colSurfaceVariant
    property color colHandle: Theme.colOnPrimary
    property color colHandleInactive: Theme.colOnSurfaceVariant

    implicitHeight: 32
    implicitWidth: 52

    indicator: Rectangle {
        implicitWidth: 52
        implicitHeight: 32
        x: root.leftPadding
        y: parent.height / 2 - height / 2
        radius: height / 2
        color: root.checked ? root.colActive : root.colInactive

        Behavior on color {
            ColorAnimation { duration: Theme.animation.fast }
        }

        Rectangle {
            x: root.checked ? parent.width - width - 4 : 4
            y: 4
            width: root.checked ? 30 : 24
            height: root.checked ? 24 : 24
            radius: height / 2
            color: root.checked ? root.colHandle : root.colHandleInactive

            Behavior on x {
                NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animation.fast }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.iconText.length > 0
                text: root.iconText
                iconSize: 16
                color: root.checked ? root.colActive : Theme.colSurface
            }
        }
    }

    contentItem: StyledText {
        text: root.text
        color: Theme.colOnSurface
        leftPadding: root.indicator.width + 8
        visible: root.text.length > 0
    }
}
