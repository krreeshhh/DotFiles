import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

Item {
    id: root
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Theme.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: [
                { icon: "screenshot_region", action: "screenshot", show: true },
                { icon: "mic", action: "mic", show: true }
            ]

            delegate: RippleButton {
                id: utilButton
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                visible: modelData.show
                buttonRadius: Theme.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer1Hover
                colRipple: Theme.colLayer1Active
                downAction: () => {
                    if (modelData.action === "screenshot")
                        Quickshell.execDetached([(Quickshell.env ? Quickshell.env("HOME") : "") + "/.config/hypr/scripts/screenshot.sh"]);
                    else if (modelData.action === "mic")
                        Audio.toggleMicMute();
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: modelData.action === "mic" && Audio.micMuted ? "mic_off" : modelData.icon
                    iconSize: 18
                    color: modelData.action === "mic" && Audio.micMuted ? Theme.colorError : Theme.colOnLayer2
                }
            }
        }
    }
}
