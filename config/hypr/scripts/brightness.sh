#!/usr/bin/env bash
# Brightness Controller & OSD Trigger

set -euo pipefail

ACTION="${1:-get}"
STEP="5%"

case "$ACTION" in
    up)
        brightnessctl -e4 -n2 set "+${STEP}" >/dev/null 2>&1 || brightnessctl set "+${STEP}" >/dev/null 2>&1
        ;;
    down)
        brightnessctl -e4 -n2 set "${STEP}-" >/dev/null 2>&1 || brightnessctl set "${STEP}-" >/dev/null 2>&1
        ;;
    set)
        VAL="${2:-50}"
        brightnessctl -e4 -n2 set "${VAL}%" >/dev/null 2>&1 || brightnessctl set "${VAL}%" >/dev/null 2>&1
        ;;
    get)
        ;;
    *)
        echo "Usage: $0 {up|down|set <pct>|get}"
        exit 1
        ;;
esac

# Read current brightness percentage
BRIGHT_PCT=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%' || echo "50")
BRIGHT_INT=$(printf '%.0f' "$BRIGHT_PCT" 2>/dev/null || echo "50")

# Dispatch to Quickshell OSD
if command -v quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/quickshell" call osd brightness "$BRIGHT_INT" >/dev/null 2>&1 || true
fi

echo "$BRIGHT_INT"
