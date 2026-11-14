import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 button with expressive bounciness.
 */
Button {
    id: root
    property bool toggled
    property string buttonText
    property real buttonRadius: Theme.rounding.small
    property real buttonRadiusPressed: Theme.rounding.verySmall
    property var downAction
    property var releaseAction
    property var altAction
    property var middleClickAction
    property bool bounce: true
    property real baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    property real baseHeight: contentItem.implicitHeight + verticalPadding * 2
    property bool enableImplicitWidthAnimation: true
    property bool enableImplicitHeightAnimation: true
    property real clickedWidth: baseWidth + (isAtSide ? 10 : 20)
    property real clickedHeight: baseHeight
    property var parentGroup: root.parent
    property int indexInParent: parentGroup?.children.indexOf(root) ?? -1
    property int clickIndex: parentGroup?.clickIndex ?? -1
    property bool isAtSide: indexInParent === 0 || indexInParent === (parentGroup?.childrenCount - 1)

    Layout.fillWidth: (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    Layout.fillHeight: (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    implicitWidth: (root.down && bounce) ? clickedWidth : baseWidth
    implicitHeight: (root.down && bounce) ? clickedHeight : baseHeight

    property color colBackground: "transparent"
    property color colBackgroundHover: Theme.colLayer1Hover
    property color colBackgroundActive: Theme.colLayer1Active
    property color colBackgroundToggled: Theme.colPrimary
    property color colBackgroundToggledHover: Theme.alpha(Theme.colPrimary, 0.86)
    property color colBackgroundToggledActive: Theme.alpha(Theme.colPrimary, 0.75)

    property real radius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real leftRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real rightRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property color color: root.enabled ? (root.toggled
        ? (root.down ? colBackgroundToggledActive
            : root.hovered ? colBackgroundToggledHover
            : colBackgroundToggled)
        : (root.down ? colBackgroundActive
            : root.hovered ? colBackgroundHover
            : colBackground)) : colBackground

    onDownChanged: {
        if (root.down) {
            if (root.parent.clickIndex !== undefined) {
                root.parent.clickIndex = parent.children.indexOf(root);
            }
        }
    }

    Behavior on implicitWidth {
        enabled: root.enableImplicitWidthAnimation
        NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        enabled: root.enableImplicitHeightAnimation
        NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
    }
    Behavior on leftRadius {
        NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
    }
    Behavior on rightRadius {
        NumberAnimation { duration: Theme.animation.fast; easing.type: Easing.OutCubic }
    }

    property alias mouseArea: buttonMouseArea
    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                if (root.altAction) root.altAction();
                return;
            }
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction) root.middleClickAction();
                return;
            }
            root.down = true;
            if (root.downAction) root.downAction();
        }
        onReleased: (event) => {
            root.down = false;
            if (event.button !== Qt.LeftButton) return;
            if (root.releaseAction) root.releaseAction();
        }
        onClicked: (event) => {
            if (event.button !== Qt.LeftButton) return;
            root.click();
        }
        onCanceled: root.down = false
        onPressAndHold: {
            if (root.altAction) root.altAction();
            root.down = false;
        }
    }

    background: Rectangle {
        id: buttonBackground
        topLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomLeftRadius: root.leftRadius
        bottomRightRadius: root.rightRadius
        implicitHeight: 50

        color: root.color
        Behavior on color {
            ColorAnimation { duration: Theme.animation.fast }
        }

        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.colSecondary
    }

    contentItem: StyledText {
        text: root.buttonText
    }
}
