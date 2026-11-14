import ".."
import QtQuick

Text {
    id: root
    property bool animateChange: false
    property real animationDistanceX: 0
    property real animationDistanceY: 6

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: Theme.font.family.main
        pixelSize: Theme.font.pixelSize.small
        variableAxes: root.shouldUseNumberFont ? ({}) : Theme.font.variableAxes.main
    }
    color: Theme.colOnSurface
    linkColor: Theme.primary

    component Anim: NumberAnimation {
        target: root
        duration: Theme.animation.fast
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: {
        textAnimationBehavior.originalX = root.x;
        textAnimationBehavior.originalY = root.y;
    }

    Behavior on text {
        id: textAnimationBehavior
        property real originalX: root.x
        property real originalY: root.y
        enabled: root.animateChange

        SequentialAnimation {
            alwaysRunToEnd: true
            ParallelAnimation {
                Anim { property: "x"; to: textAnimationBehavior.originalX - root.animationDistanceX; easing.type: Easing.InSine }
                Anim { property: "y"; to: textAnimationBehavior.originalY - root.animationDistanceY; easing.type: Easing.InSine }
                Anim { property: "opacity"; to: 0; easing.type: Easing.InSine }
            }
            PropertyAction {}
            PropertyAction { target: root; property: "x"; value: textAnimationBehavior.originalX + root.animationDistanceX }
            PropertyAction { target: root; property: "y"; value: textAnimationBehavior.originalY + root.animationDistanceY }
            ParallelAnimation {
                Anim { property: "x"; to: textAnimationBehavior.originalX; easing.type: Easing.OutSine }
                Anim { property: "y"; to: textAnimationBehavior.originalY; easing.type: Easing.OutSine }
                Anim { property: "opacity"; to: 1; easing.type: Easing.OutSine }
            }
        }
    }
}
