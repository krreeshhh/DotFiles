#!/usr/bin/env bash
# ==========================================================
# launch.sh - Quickshell Desktop Shell Launcher
# ==========================================================
set -euo pipefail

# Ensure environment
export QT_QPA_PLATFORM=wayland
export XDG_CURRENT_DESKTOP=Hyprland

# Export QML module search paths for qs.Commons, qs.Ui, and plugins
export QML_IMPORT_PATH="$HOME/.config/quickshell:$HOME/.config/quickshell/plugins:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$HOME/.config/quickshell:$HOME/.config/quickshell/plugins:${QML2_IMPORT_PATH:-}"

# Kill existing instances (with safe bounded timeout)
killall -q quickshell || true
for _ in {1..20}; do
    if ! pgrep -x quickshell >/dev/null; then break; fi
    sleep 0.05
done

# Start quickshell
exec quickshell -p "$HOME/.config/quickshell"
