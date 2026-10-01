import QtQuick
import QtQuick.Window
import QtMultimedia

Item {
    id: videoContainer
    anchors.fill: parent

    MediaPlayer {
        id: mediaplayer
        source: "bg.mp4"
        loops: MediaPlayer.Infinite
        videoOutput: videoOutput
        Component.onCompleted: {
            mediaplayer.play()
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
