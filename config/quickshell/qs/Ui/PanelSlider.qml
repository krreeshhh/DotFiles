import QtQuick
import QtQuick.Controls
import "../Commons"

Item {
    id: root

    property var bar: null
    property real minimum: 0.0
    property real maximum: 1.0
    property real step: 0.01
    property bool integer: false
    property real value: minimum

    property real liveValue: value
    property bool dragging: mouseArea.pressed

    property color accent: Color.accent
    property color foreground: Color.foreground
    property color trackColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
    property color highlightColor: Color.accent

    signal moved(real value)
    signal released(real value)

    implicitWidth: 200
    implicitHeight: 28

    onValueChanged: {
        if (!root.dragging) {
            root.liveValue = root.value;
        }
    }

    function snap(v) {
        if (root.integer) {
            v = Math.round(v);
        } else if (root.step > 0) {
            var steps = Math.round((v - root.minimum) / root.step);
            v = root.minimum + steps * root.step;
        }
        return Math.max(root.minimum, Math.min(root.maximum, v));
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: root.trackColor

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 3
            color: root.highlightColor
            width: Math.max(0, Math.min(track.width, ((root.liveValue - root.minimum) / (root.maximum - root.minimum || 1)) * track.width))
        }
    }

    Rectangle {
        id: thumb
        width: 14
        height: 14
        radius: 7
        color: root.accent
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(root.width - width, ((root.liveValue - root.minimum) / (root.maximum - root.minimum || 1)) * (root.width - width)))

        scale: root.dragging ? 1.25 : (mouseArea.containsMouse ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 80 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFromMouse(mouse) {
            var norm = Math.max(0, Math.min(1, mouse.x / mouseArea.width));
            var raw = root.minimum + norm * (root.maximum - root.minimum);
            var snapped = root.snap(raw);
            root.liveValue = snapped;
            root.moved(snapped);
        }

        onPressed: (mouse) => {
            updateFromMouse(mouse);
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                updateFromMouse(mouse);
            }
        }

        onReleased: (mouse) => {
            var norm = Math.max(0, Math.min(1, mouse.x / mouseArea.width));
            var raw = root.minimum + norm * (root.maximum - root.minimum);
            var snapped = root.snap(raw);
            root.liveValue = snapped;
            root.released(snapped);
        }
    }
}
