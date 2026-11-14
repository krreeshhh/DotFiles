import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import ".."
import "../services"
import "../lib"

Item {
    id: root
    readonly property var activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: (activePlayer?.trackTitle ?? "").replace(/\s*[\(\[].*?[\)\]]\s*/g, " ").trim()

    Layout.fillHeight: true
    implicitWidth: rowLayout.implicitWidth + 8
    implicitHeight: Theme.sizes.barHeight
    visible: MprisController.hasPlayer

    Timer {
        running: MprisController.isPlaying
        interval: 1000
        repeat: true
        onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) MprisController.togglePlaying();
            else if (event.button === Qt.BackButton) MprisController.previous();
            else if (event.button === Qt.ForwardButton) MprisController.next();
            else if (event.button === Qt.LeftButton) GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 4

        ClippedFilledCircularProgress {
            id: mediaCircProg
            Layout.alignment: Qt.AlignVCenter
            lineWidth: 2
            value: MprisController.progress
            implicitSize: 20
            colPrimary: Theme.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: MprisController.isPlaying ? "pause" : "music_note"
                    iconSize: 14
                    color: Theme.colOnSecondaryContainer
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
            color: Theme.colOnLayer1
            font.pixelSize: Theme.font.pixelSize.smaller
            text: root.cleanedTitle + (root.activePlayer?.trackArtist ? " • " + root.activePlayer.trackArtist : "")
        }
    }
}
