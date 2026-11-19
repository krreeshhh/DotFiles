#!/usr/bin/env bash
# Volume & Audio Controller with OSD Trigger

set -euo pipefail

ACTION="${1:-get}"
STEP="5%"

# Volume limit is the cap for all volume changes (from Dotfiles Settings)
VOLUME_LIMIT_PCT=$(command -v jq >/dev/null 2>&1 && jq -r '.audio.protection.maxAllowed // 154' "$HOME/.config/dotfiles/config.json" 2>/dev/null || echo 154)
case "$VOLUME_LIMIT_PCT" in ''|*[!0-9.]*) VOLUME_LIMIT_PCT=154;; esac
VOLUME_LIMIT=$(python3 -c "print(max(1, float('${VOLUME_LIMIT_PCT}')) / 100)")

case "$ACTION" in
    up)
        wpctl set-volume -l "${VOLUME_LIMIT}" @DEFAULT_AUDIO_SINK@ "${STEP}+" >/dev/null 2>&1 || true
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}-" >/dev/null 2>&1 || true
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1 || true
        ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null 2>&1 || true
        MIC_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo "Volume: 1.0")
        MIC_MUTED=false
        if echo "$MIC_RAW" | grep -q '\[MUTED\]'; then
            MIC_MUTED=true
        fi
        if command -v quickshell >/dev/null 2>&1; then
            quickshell ipc -p "$HOME/.config/quickshell" call osd show "mic" 0 "$MIC_MUTED" >/dev/null 2>&1 || true
        fi
        exit 0
        ;;
    set)
        VAL="${2:-50}"
        VAL=$(python3 -c "print(min(float('$VOLUME_LIMIT_PCT'), max(0, int('$VAL'))))" 2>/dev/null || echo "$VAL")
        wpctl set-volume -l "${VOLUME_LIMIT}" @DEFAULT_AUDIO_SINK@ "${VAL}%" >/dev/null 2>&1 || true
        ;;
    get)
        ;;
    *)
        echo "Usage: $0 {up|down|mute|mic-mute|set <pct>|get}"
        exit 1
        ;;
esac

# Read current audio sink volume and mute state
VOL_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.50")
IS_MUTED=false
if echo "$VOL_RAW" | grep -q '\[MUTED\]'; then
    IS_MUTED=true
fi

VOL_NUM=$(echo "$VOL_RAW" | grep -oP '\d+(\.\d+)?' | head -n1 || echo "0.5")
VOL_PCT=$(python3 -c "import sys; print(min(100, round(float('$VOL_NUM') * 100)))" 2>/dev/null || echo "50")

# Dispatch to Quickshell OSD (dotfiles shell auto-detects; trigger as fallback)
if command -v quickshell >/dev/null 2>&1; then
    quickshell -p "$HOME/.config/quickshell/dotfiles" ipc call osdVolume trigger >/dev/null 2>&1 || \
    quickshell ipc -p "$HOME/.config/quickshell" call osd volume "$VOL_PCT" "$IS_MUTED" >/dev/null 2>&1 || true
fi

echo "$VOL_PCT% (Muted: $IS_MUTED)"
