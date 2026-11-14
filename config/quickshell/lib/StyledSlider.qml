import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 slider (simplified). Track with rounded fill + dot handle.
 */
Slider {
    id: root

    property color highlightColor: Theme.colPrimary
    property color trackColor: Theme.colSecondaryContainer
    property color handleColor: Theme.colPrimary
    property color dotColor: Theme.colOnSecondaryContainer
    property color dotColorHighlighted: Theme.colOnPrimary
    property real trackWidth: 18
    property real handleSize: 4
    property bool usePercentTooltip: true

    Layout.fillWidth: true
    from: 0
    to: 1

    Behavior on value {
        SmoothedAnimation { velocity: 6 }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => mouse.accepted = false
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    background: Item {
        id: background
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width - root.leftPadding - root.rightPadding
        implicitHeight: root.trackWidth

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: root.trackColor
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: Math.max(height, parent.width * root.visualPosition)
            radius: Theme.rounding.full
            color: root.highlightColor
            Behavior on width {
                NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.handleSize + (root.pressed ? 3 : 0)
        implicitHeight: 32
        radius: implicitWidth / 2
        color: root.handleColor
        Behavior on implicitWidth {
            NumberAnimation { duration: Theme.animation.fast }
        }
    }
}
