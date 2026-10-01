#!/usr/bin/env bash
# ==========================================================
# switch.sh - Seamless Switcher between Waybar & Quickshell
# ==========================================================
set -euo pipefail

MODE="${1:---toggle}"

case "$MODE" in
    --quickshell)
        echo "Switching to Quickshell..."
        pkill -x waybar >/dev/null 2>&1 || true
        pkill -x quickshell >/dev/null 2>&1 || true
        quickshell -d -p "$HOME/.config/quickshell"
        echo "Quickshell active!"
        ;;
    --waybar)
        echo "Switching to Waybar..."
        pkill -x quickshell >/dev/null 2>&1 || true
        pkill -x waybar >/dev/null 2>&1 || true
        waybar >/tmp/waybar.log 2>&1 &
        echo "Waybar active!"
        ;;
    --toggle)
        if pgrep -x quickshell >/dev/null 2>&1; then
            "$0" --waybar
        else
            "$0" --quickshell
        fi
        ;;
    --rollback)
        LATEST_BACKUP=$(find "$HOME/.config" -maxdepth 1 -type d -name "desktop_backup_*" | sort -r | head -n 1)
        if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
            echo "Rolling back from: $LATEST_BACKUP"
            pkill -x quickshell >/dev/null 2>&1 || true
            pkill -x waybar >/dev/null 2>&1 || true
            cp -r "$LATEST_BACKUP/waybar" "$HOME/.config/"
            cp -r "$LATEST_BACKUP/my-desktop" "$HOME/.config/"
            cp -r "$LATEST_BACKUP/hypr" "$HOME/.config/" 2>/dev/null || true
            waybar >/dev/null 2>&1 &
            echo "Rollback complete! Waybar restored."
        else
            echo "No backup found in ~/.config/"
        fi
        ;;
    *)
        echo "Usage: $0 [--quickshell | --waybar | --toggle | --rollback]"
        exit 1
        ;;
esac
