#!/usr/bin/env bash
# Brightness Controller, routes through the Dotfiles shell's Brightness
# service so the OSD popup shows (like the volume OSD) and the right-sidebar
# slider tracks the current value. Falls back to brightnessctl if the shell
# is not running.

set -euo pipefail

ACTION="${1:-get}"
STEP="5%"

if command -v quickshell >/dev/null 2>&1 && \
   quickshell -p "${HOME}/.config/quickshell/dotfiles" ipc show >/dev/null 2>&1; then    case "$ACTION" in
        up|down|set)
            case "$ACTION" in
                up)   quickshell -p "${HOME}/.config/quickshell/dotfiles" ipc call brightness increment >/dev/null;;
                down) quickshell -p "${HOME}/.config/quickshell/dotfiles" ipc call brightness decrement >/dev/null;;
                set)
                    VAL="${2:-50}"
                    # No IPC setter; apply via brightnessctl and let the shell pick it up on next sync
                    brightnessctl set "${VAL}%" >/dev/null 2>&1 || true
                    ;;
            esac
            exit 0
            ;;
        get) ;;
        *)
            echo "Usage: $0 {up|down|set <pct>|get}"
            exit 1
            ;;
    esac
fi

# Fallback (shell not running)
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

if command -v brightnessctl >/dev/null 2>&1; then
    BRIGHT_PCT=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%' || echo "50")
    printf '%.0f\n' "$BRIGHT_PCT"
fi
