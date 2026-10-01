#!/usr/bin/env bash
# ==========================================================
# screenshot.sh - Hyprland Screenshot Tool with Native Clipboard & Rich Notification
# ==========================================================
set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILE="$DIR/Screenshot_${TIMESTAMP}.png"
MODE="${1:-area}"

# Load dynamic Material You theme colors if available
THEME_CONF="$HOME/.config/my-desktop/theme/colors.conf"
if [ -f "$THEME_CONF" ]; then
    # shellcheck source=/dev/null
    source "$THEME_CONF"
fi

BORDER_COL="${PRIMARY:-#d88cad}"
BG_COL="${BACKGROUND:-#130f12}"

# Copy image to clipboard via wl-copy (with Python GTK fallback)
copy_to_clipboard() {
    local target="$1"
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy --type image/png < "$target"
    else
        python3 -c "
import gi, sys
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf

try:
    pixbuf = GdkPixbuf.Pixbuf.new_from_file(sys.argv[1])
    cb = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    cb.set_image(pixbuf)
    cb.store()
except Exception as e:
    sys.stderr.write(f'Clipboard error: {e}\n')
" "$target" 2>/dev/null || true
    fi
}

# Capture screen or area
if [ "$MODE" = "full" ]; then
    grim "$FILE"
else
    # Area selection via slurp with Material You theme colors
    GEOM=$(slurp -d -b "${BG_COL}aa" -c "${BORDER_COL}ff" -s "${BORDER_COL}33" -w 2 || true)
    if [ -z "$GEOM" ]; then
        # Selection was cancelled
        exit 0
    fi
    
    # Crucial: Allow Wayland compositor to destroy slurp overlay surface before capturing framebuffer
    sleep 0.15
    grim -g "$GEOM" "$FILE"
fi

if [ -f "$FILE" ]; then
    # 1. Automatically copy to clipboard
    copy_to_clipboard "$FILE"

    # 2. Send rich interactive notification with preview
    if command -v notify-send >/dev/null 2>&1; then
        ACTION=$(notify-send -u normal \
            -i "$FILE" \
            -a "Screenshot" \
            -A "open=🖼️ Open" \
            -A "folder=📁 Show in Folder" \
            -A "delete=🗑️ Delete" \
            "📸 Screenshot Captured" \
            "Saved to Screenshots & copied to clipboard." || true)

        case "$ACTION" in
            "open")
                xdg-open "$FILE" >/dev/null 2>&1 &
                ;;
            "folder")
                xdg-open "$DIR" >/dev/null 2>&1 &
                ;;
            "delete")
                rm -f "$FILE"
                notify-send -u low -t 2000 -a "Screenshot" "Screenshot Deleted" "File removed."
                ;;
        esac
    fi
fi
