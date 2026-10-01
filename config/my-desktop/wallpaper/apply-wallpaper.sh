#!/usr/bin/env bash
# ==========================================================
# apply-wallpaper.sh - Modular Wallpaper & Theme Switcher
# ==========================================================
set -euo pipefail

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

STATE_FILE="${STATE_FILE:-$HOME/.config/my-desktop/wallpaper/current}"
DEFAULT_WALLPAPER="${DEFAULT_WALLPAPER:-$HOME/.wallpaper/Wall.png}"
WALLPAPER_MODE="${WALLPAPER_MODE:-crop}"
WALLPAPER_BACKEND="${WALLPAPER_BACKEND:-awww}"

# Transition defaults
TRANSITION_TYPE="${TRANSITION_TYPE:-grow}"
TRANSITION_POS="${TRANSITION_POS:-cursor}"
TRANSITION_DURATION="${TRANSITION_DURATION:-1.4}"
TRANSITION_FPS="${TRANSITION_FPS:-144}"
TRANSITION_BEZIER="${TRANSITION_BEZIER:-.25,1,.5,1}"
TRANSITION_STEP="${TRANSITION_STEP:-90}"

TARGET_WALLPAPER="${1:-}"

# Resolve target wallpaper from arguments, state, or fallback
if [ -z "$TARGET_WALLPAPER" ]; then
    if [ -f "$STATE_FILE" ]; then
        TARGET_WALLPAPER=$(cat "$STATE_FILE")
    fi
fi

if [ -z "$TARGET_WALLPAPER" ] || [ ! -f "$TARGET_WALLPAPER" ]; then
    TARGET_WALLPAPER="$DEFAULT_WALLPAPER"
fi

if [ ! -f "$TARGET_WALLPAPER" ]; then
    echo "Error: Target wallpaper file not found: $TARGET_WALLPAPER" >&2
    exit 1
fi

# Ensure state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# 1. Apply wallpaper using selected backend
if [ "$WALLPAPER_BACKEND" = "awww" ] || [ "$WALLPAPER_BACKEND" = "swww" ]; then
    # Kill any lingering swaybg instances so they do not overlay
    pkill -x swaybg >/dev/null 2>&1 || true

    # Choose binary: prefer awww, fallback to swww
    BACKEND_BIN="awww"
    DAEMON_BIN="awww-daemon"
    if ! command -v awww >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
        BACKEND_BIN="swww"
        DAEMON_BIN="swww-daemon"
    fi

    # Ensure daemon is running
    if ! pgrep -x "$DAEMON_BIN" >/dev/null 2>&1; then
        "$DAEMON_BIN" >/dev/null 2>&1 &
        sleep 0.25
    fi

    # Resolve transition position
    ACTUAL_POS="$TRANSITION_POS"
    if [ "$ACTUAL_POS" = "cursor" ]; then
        if command -v hyprctl >/dev/null 2>&1; then
            CURSOR=$(hyprctl cursorpos 2>/dev/null | tr -d ' ' || true)
            if [ -n "$CURSOR" ]; then
                ACTUAL_POS="$CURSOR"
            else
                ACTUAL_POS="center"
            fi
        else
            ACTUAL_POS="center"
        fi
    fi

    # Map wallpaper mode to awww resize argument
    RESIZE_ARG="crop"
    case "$WALLPAPER_MODE" in
        fill|crop) RESIZE_ARG="crop" ;;
        fit) RESIZE_ARG="fit" ;;
        stretch) RESIZE_ARG="stretch" ;;
        center|no) RESIZE_ARG="no" ;;
        *) RESIZE_ARG="crop" ;;
    esac

    # Execute animated wallpaper change
    "$BACKEND_BIN" img "$TARGET_WALLPAPER" \
        --resize "$RESIZE_ARG" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-pos "$ACTUAL_POS" \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS" \
        --transition-bezier "$TRANSITION_BEZIER" \
        --transition-step "$TRANSITION_STEP" >/dev/null 2>&1 || true

else
    # Fallback to swaybg
    OLD_PIDS=$(pgrep -x swaybg || true)
    swaybg -i "$TARGET_WALLPAPER" -m "$WALLPAPER_MODE" >/dev/null 2>&1 &
    NEW_PID=$!
    sleep 0.15
    if [ -n "$OLD_PIDS" ]; then
        for pid in $OLD_PIDS; do
            if [ "$pid" != "$NEW_PID" ]; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
fi

# Update state file
echo "$TARGET_WALLPAPER" > "$STATE_FILE"

# Apply dynamic Material You theme if enabled
if [ "${ENABLE_DYNAMIC_THEME:-true}" = "true" ]; then
    THEME_APPLY="$HOME/.config/my-desktop/theme/apply-theme.sh"
    if [ -f "$THEME_APPLY" ]; then
        bash "$THEME_APPLY" "$TARGET_WALLPAPER"
    fi
fi

# Update GRUB theme background asynchronously in the background
if command -v update-grub-wallpaper >/dev/null 2>&1; then
    sudo -n update-grub-wallpaper --quiet >/dev/null 2>&1 &
elif [ -f "$HOME/Dotfiles/scripts/grub-wallpaper-randomizer.py" ]; then
    python3 "$HOME/Dotfiles/scripts/grub-wallpaper-randomizer.py" --quiet >/dev/null 2>&1 &
fi

# Send desktop notification
WP_BASENAME=$(basename "$TARGET_WALLPAPER")
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -i "$TARGET_WALLPAPER" "Wallpaper Applied" "$WP_BASENAME" 2>/dev/null || true
fi

echo "Successfully applied wallpaper: $TARGET_WALLPAPER"
exit 0
