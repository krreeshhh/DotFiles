import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Rectangle {
    id: root

    implicitHeight: content.implicitHeight + 20
    radius: Theme.rounding.normal
    color: Theme.colLayer1
    border.width: 1
    border.color: Theme.colLayer1Border

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
            topMargin: 10
            bottomMargin: 10
        }
        spacing: 2

        RowLayout {
            visible: Config.options.sidebar.quickSliders.showBrightness
            Layout.fillWidth: true
            spacing: 10
            MaterialSymbol {
                text: "light_mode"
                iconSize: 20
                color: Theme.colOnLayer1
            }
            StyledSlider {
                Layout.fillWidth: true
                value: Brightness.brightness
                onMoved: Brightness.setBrightness(value)
            }
            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(Brightness.brightness * 100) + "%"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
        }

        RowLayout {
            visible: Config.options.sidebar.quickSliders.showVolume
            Layout.fillWidth: true
            spacing: 10
            MaterialSymbol {
                text: Audio.muted ? "volume_off" : "volume_up"
                iconSize: 20
                color: Theme.colOnLayer1
            }
            StyledSlider {
                Layout.fillWidth: true
                value: Audio.volume
                onMoved: Audio.setVolume(value)
            }
            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(Audio.volume * 100) + "%"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
        }

        RowLayout {
            visible: Config.options.sidebar.quickSliders.showMic
            Layout.fillWidth: true
            spacing: 10
            MaterialSymbol {
                text: Audio.micMuted ? "mic_off" : "mic"
                iconSize: 20
                color: Theme.colOnLayer1
            }
            StyledSlider {
                Layout.fillWidth: true
                value: Audio.micVolume
                onMoved: Audio.setMicVolume(value)
            }
            StyledText {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(Audio.micVolume * 100) + "%"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
        }
    }
}
