import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TabButton {
    id: root

    property bool toggled: TabBar.tabBar.currentIndex === TabBar.index
    property string buttonIcon
    property real buttonIconRotation: 0
    property string buttonText
    property bool expanded: false
    property bool showToggledHighlight: true
    readonly property real visualWidth: root.expanded ? root.baseSize + 20 + itemText.implicitWidth : root.baseSize

    property real baseSize: 56
    property real baseHighlightHeight: 32
    property real highlightCollapsedTopMargin: 8
    padding: 0

    Layout.fillWidth: true
    implicitHeight: baseSize

    background: null
    PointingHandInteraction {}

    contentItem: Item {
        id: buttonContent
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: undefined
        }

        implicitWidth: root.visualWidth
        implicitHeight: root.expanded ? itemIconBackground.implicitHeight : itemIconBackground.implicitHeight + itemText.implicitHeight

        Rectangle {
            id: itemBackground
            anchors.top: itemIconBackground.top
            anchors.left: itemIconBackground.left
            anchors.bottom: itemIconBackground.bottom
            implicitWidth: root.visualWidth
            radius: Theme.rounding.full
            color: toggled
                ? (root.showToggledHighlight
                    ? (root.down ? Theme.alpha(Theme.colSecondaryContainer, 0.8)
                        : root.hovered ? Theme.alpha(Theme.colSecondaryContainer, 0.9)
                        : Theme.colSecondaryContainer)
                    : "transparent")
                : (root.down ? Theme.colLayer1Active
                    : root.hovered ? Theme.colLayer1Hover
                    : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.animation.fast }
            }
        }

        Item {
            id: itemIconBackground
            implicitWidth: root.baseSize
            implicitHeight: root.baseHighlightHeight
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            MaterialSymbol {
                id: navRailButtonIcon
                rotation: root.buttonIconRotation
                anchors.centerIn: parent
                iconSize: 24
                fill: toggled ? 1 : 0
                font.weight: (toggled || root.hovered) ? Font.DemiBold : Font.Normal
                text: buttonIcon
                color: toggled ? Theme.colOnSecondaryContainer : Theme.colOnLayer1

                Behavior on color {
                    ColorAnimation { duration: Theme.animation.fast }
                }
            }
        }

        StyledText {
            id: itemText
            anchors {
                top: itemIconBackground.bottom
                topMargin: 2
                horizontalCenter: itemIconBackground.horizontalCenter
            }
            text: buttonText
            font.pixelSize: 14
            color: Theme.colOnLayer1
            visible: text.length > 0
        }
    }
}
