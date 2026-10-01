import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root
    property var modelData: null
    screen: modelData

    anchors {
        bottom: true
    }
    margins {
        bottom: 60
    }

    implicitWidth: 280
    implicitHeight: 52
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool shown: false
    property string osdType: "volume" // "volume", "brightness", "mic"
    property int value: 50
    property bool isMuted: false

    visible: osdCard.opacity > 0.01

    function trigger(type, val, muted) {
        osdType = type;
        value = Math.max(0, Math.min(100, val));
        isMuted = !!muted;
        shown = true;
        hideTimer.restart();
    }

    function getIcon() {
        if (osdType === "brightness") {
            if (value >= 66) return "󰃠";
            if (value >= 33) return "󰃟";
            return "󰃞";
        }
        if (osdType === "mic") {
            return isMuted ? "󰍭" : "󰍬";
        }
        // Volume
        if (isMuted || value === 0) return "󰝟";
        if (value >= 66) return "󰕾";
        if (value >= 33) return "󰖀";
        return "󰕿";
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: root.shown = false
    }

    Rectangle {
        id: osdCard
        anchors.fill: parent
        radius: 16
        color: Theme.popupSurface
        border.color: Theme.popupBorder
        border.width: 1
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                text: root.getIcon()
                font.family: Theme.fontFamily
                font.pixelSize: 20
                color: root.isMuted ? Theme.colorError : Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 7
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 3.5
                    color: Theme.popupSurfaceVariant
                }

                Rectangle {
                    height: parent.height
                    width: Math.max(0, Math.min(parent.width, parent.width * (root.value / 100)))
                    radius: 3.5
                    color: root.isMuted ? Theme.colOnSurfaceVariant : Theme.primary

                    Behavior on width {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                text: root.isMuted ? "MUTE" : (root.value + "%")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.isMuted ? Theme.colorError : Theme.colOnSurface
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
