import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

Item {
    id: root
    visible: {
        if (!activePlayer) return false;
        if (activePlayer.playbackState === MprisPlaybackState.Stopped) return false;
        if (activePlayer.playbackState === MprisPlaybackState.Playing) return true;
        var t = (activePlayer.trackTitle || "").trim();
        var a = (activePlayer.trackArtist || "").trim();
        return (t.length > 0 || a.length > 0);
    }
    implicitWidth: visible ? mediaRow.implicitWidth + 12 : 0
    implicitHeight: parent ? parent.height : 36
    width: implicitWidth
    height: implicitHeight

    property var activePlayer: null

    function updateActivePlayer(changedPlayer) {
        var players = Mpris.players.values || [];

        // 1. If a specific player just transitioned to Playing, make it active immediately
        if (changedPlayer && changedPlayer.playbackState === MprisPlaybackState.Playing) {
            root.activePlayer = changedPlayer;
            return;
        }

        // 2. Check if any player in the system is currently Playing
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) {
                root.activePlayer = p;
                return;
            }
        }

        // 3. If no player is currently Playing, keep current activePlayer if still valid and not Stopped
        if (root.activePlayer) {
            var stillExists = false;
            for (var j = 0; j < players.length; j++) {
                if (players[j] === root.activePlayer) {
                    stillExists = true;
                    break;
                }
            }
            if (stillExists && root.activePlayer.playbackState !== MprisPlaybackState.Stopped) {
                var currentTitle = (root.activePlayer.trackTitle || "").trim();
                var currentArtist = (root.activePlayer.trackArtist || "").trim();
                if (currentTitle.length > 0 || currentArtist.length > 0) {
                    return;
                }
            }
        }

        // 4. If current activePlayer is no longer valid, look for any Paused player with track metadata
        for (var k = 0; k < players.length; k++) {
            var player = players[k];
            if (player && player.playbackState !== MprisPlaybackState.Stopped) {
                var title = (player.trackTitle || "").trim();
                var artist = (player.trackArtist || "").trim();
                if (title.length > 0 || artist.length > 0) {
                    root.activePlayer = player;
                    return;
                }
            }
        }

        // 5. No valid playing or paused player found
        root.activePlayer = null;
    }

    Component.onCompleted: {
        root.updateActivePlayer();
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.updateActivePlayer();
        }
    }

    Repeater {
        model: Mpris.players.values
        Item {
            Connections {
                target: modelData
                function onPlaybackStateChanged() {
                    root.updateActivePlayer(modelData);
                }
                function onTrackTitleChanged() {
                    if (!root.activePlayer || root.activePlayer.playbackState !== MprisPlaybackState.Playing) {
                        root.updateActivePlayer();
                    }
                }
            }
        }
    }

    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: mediaIcon
            text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? " " : "⏸ "
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: mouseArea.containsMouse ? Theme.colOnSurface : ((root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? Theme.primary : Theme.colOnSurfaceVariant)
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: mediaTitle
            text: {
                if (!root.activePlayer) return "";
                var t = (root.activePlayer.trackTitle || "").trim();
                var a = (root.activePlayer.trackArtist || "").trim();
                var str = t + (a ? (t ? " - " : "") + a : "");
                if (!str && root.activePlayer.playbackState === MprisPlaybackState.Playing) {
                    str = root.activePlayer.identity || "Media";
                }
                if (str.length > 32) return str.substring(0, 31) + "…";
                return str;
            }
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: mouseArea.containsMouse ? Theme.colOnSurface : ((root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? Theme.primary : Theme.colOnSurfaceVariant)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (!root.activePlayer) {
                Quickshell.execDetached(["playerctl", "play-pause"]);
                return;
            }
            if (mouse.button === Qt.LeftButton) {
                if (typeof root.activePlayer.togglePlaying === "function") {
                    root.activePlayer.togglePlaying();
                } else if (root.activePlayer.playbackState === MprisPlaybackState.Playing) {
                    root.activePlayer.pause();
                } else {
                    root.activePlayer.play();
                }
            } else if (mouse.button === Qt.RightButton) {
                if (typeof root.activePlayer.next === "function") {
                    root.activePlayer.next();
                } else {
                    Quickshell.execDetached(["playerctl", "next"]);
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (typeof root.activePlayer.previous === "function") {
                    root.activePlayer.previous();
                } else {
                    Quickshell.execDetached(["playerctl", "previous"]);
                }
            }
        }
    }
}
