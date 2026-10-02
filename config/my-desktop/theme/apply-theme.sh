#!/usr/bin/env bash
# ==========================================================
# apply-theme.sh - Apply & Propagate Dynamic Material Theme
# ==========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$HOME/.config/my-desktop/theme"
WALLPAPER="${1:-}"

# Fallback to current wallpaper state if no parameter passed
if [ -z "$WALLPAPER" ]; then
    STATE_FILE="$HOME/.config/my-desktop/wallpaper/current"
    if [ -f "$STATE_FILE" ]; then
        WALLPAPER=$(cat "$STATE_FILE")
    else
        WALLPAPER="$HOME/.wallpaper/Wall.png"
    fi
fi

# Run dynamic theme generator
python3 "$SCRIPT_DIR/generate-theme.py" "$WALLPAPER"

# Source generated colors
if [ -f "$THEME_DIR/colors.conf" ]; then
    # shellcheck source=/dev/null
    source "$THEME_DIR/colors.conf"
fi

# Update state symlink
ln -sf "$THEME_DIR/colors.conf" "$THEME_DIR/current"

# 1. Update Dunst Notification Colors
if command -v dunstctl >/dev/null 2>&1 && [ -n "${PRIMARY:-}" ]; then
    DUNSTRC="$HOME/.config/dunst/dunstrc"
    if [ -f "$DUNSTRC" ]; then
        sed -i -E "s/color='#([0-9a-fA-F]{6})'/color='${PRIMARY}'/g" "$DUNSTRC" 2>/dev/null || true
        sed -i -E "s/frame_color = \"#[0-9a-fA-F]{6}\"/frame_color = \"${PRIMARY}\"/g" "$DUNSTRC" 2>/dev/null || true
        sed -i -E "s/highlight = \"#[0-9a-fA-F]{6}\"/highlight = \"${PRIMARY}\"/g" "$DUNSTRC" 2>/dev/null || true
        if [ -n "${SURFACE:-}" ]; then
            sed -i -E "s/background = \"#[0-9a-fA-F]{6}\"/background = \"${SURFACE}\"/g" "$DUNSTRC" 2>/dev/null || true
        fi
        dunstctl reload 2>/dev/null || killall dunst 2>/dev/null || true
    fi
fi

# 2. Update Waybar (reloads styling seamlessly without resetting workspace)
if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar 2>/dev/null || true
elif command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet waybar-app; then
    systemctl --user restart waybar-app 2>/dev/null || true
fi

# 3. Update Terminal (if running)
if pgrep -x kitty >/dev/null 2>&1; then
    pkill -SIGUSR1 kitty 2>/dev/null || true
fi

# 4. Update Walker Launcher (reloads dynamic GTK4 style)
if pgrep -f "walker" >/dev/null 2>&1; then
    killall walker 2>/dev/null || true
    sleep 0.1
    walker --gapplication-service >/dev/null 2>&1 &
fi

# 5. Update Hyprland Window Borders dynamically
if command -v hyprctl >/dev/null 2>&1 && [ -n "${PRIMARY:-}" ] && [ -n "${SECONDARY:-}" ]; then
    CLEAN_PRI="${PRIMARY#\#}"
    CLEAN_SEC="${SECONDARY#\#}"
    CLEAN_OUT="${OUTLINE:-#412f3b}"
    CLEAN_OUT="${CLEAN_OUT#\#}"
    hyprctl eval "hl.config({ general = { col = { active_border = { colors = {'rgb($CLEAN_PRI)', 'rgb($CLEAN_SEC)'}, angle = 45 }, inactive_border = 'rgba(${CLEAN_OUT}aa)' } } })" >/dev/null 2>&1 || true
fi

# 6. Update Quickshell Topbar & Popups
if command -v quickshell >/dev/null 2>&1 && pgrep -x quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/quickshell" call shell reloadTheme >/dev/null 2>&1 || true
fi

# 7. Update KDE / Dolphin Theme
if command -v dbus-send >/dev/null 2>&1; then
    dbus-send --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true
fi

# 8. Update GTK, GNOME & File Chooser Portal Settings
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true
    if [ -n "${GNOME_ACCENT:-}" ]; then
        gsettings set org.gnome.desktop.interface accent-color "$GNOME_ACCENT" 2>/dev/null || true
    fi
fi

# 9. Nautilus, GTK4 & file chooser portals automatically reload styling dynamically via GSettings & CSS inotify

exit 0
