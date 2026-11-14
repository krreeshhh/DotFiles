// Active MPRIS player.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property var players: Mpris.players.values
    property var trackedPlayer: null

    readonly property var activePlayer: {
        // Prefer a playing player, then the tracked one, then anything.
        const playing = players.find(p => p.isPlaying);
        if (playing) return playing;
        if (trackedPlayer && players.indexOf(trackedPlayer) !== -1) return trackedPlayer;
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool hasPlayer: activePlayer !== null
    readonly property string trackTitle: activePlayer?.trackTitle ?? ""
    readonly property string trackArtist: activePlayer?.trackArtist ?? ""
    readonly property string trackAlbum: activePlayer?.trackAlbum ?? ""
    readonly property string trackArtUrl: activePlayer?.trackArtUrl ?? ""
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property bool canTogglePlaying: activePlayer?.canTogglePlaying ?? false
    readonly property bool canGoNext: activePlayer?.canGoNext ?? false
    readonly property bool canGoPrevious: activePlayer?.canGoPrevious ?? false
    readonly property real position: activePlayer?.position ?? 0
    readonly property real length: activePlayer?.length ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function togglePlaying() {
        if (activePlayer?.canTogglePlaying) activePlayer.togglePlaying();
    }
    function next() {
        if (activePlayer?.canGoNext) activePlayer.next();
    }
    function previous() {
        if (activePlayer?.canGoPrevious) activePlayer.previous();
    }
    function setPlayer(player) { trackedPlayer = player; }
}
