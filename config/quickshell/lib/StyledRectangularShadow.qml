import ".."
import QtQuick
import QtQuick.Effects

RectangularShadow {
    required property var target
    anchors.fill: target
    radius: target.radius ?? Theme.rounding.normal
    blur: 0.9 * Theme.sizes.elevationMargin
    offset: Qt.vector2d(0.0, 1.0)
    spread: 1
    color: Theme.alpha(Theme.shadow, 0.45)
    cached: true
}
