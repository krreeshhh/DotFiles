// PipeWire audio (default sink/source).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink?.audio ?? null
    readonly property var sourceAudio: source?.audio ?? null

    readonly property real volume: sinkAudio?.volume ?? 0
    readonly property bool muted: sinkAudio?.muted ?? false
    readonly property real micVolume: sourceAudio?.volume ?? 0
    readonly property bool micMuted: sourceAudio?.muted ?? false

    function setVolume(v) {
        if (!sinkAudio) return;
        sinkAudio.volume = Math.max(0, Math.min(1, v));
    }

    function incrementVolume(step) {
        setVolume(volume + (step ?? 0.05));
    }

    function decrementVolume(step) {
        setVolume(volume - (step ?? 0.05));
    }

    function toggleMute() {
        if (sinkAudio) sinkAudio.muted = !sinkAudio.muted;
    }

    function setMicVolume(v) {
        if (!sourceAudio) return;
        sourceAudio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (sourceAudio) sourceAudio.muted = !sourceAudio.muted;
    }
}
