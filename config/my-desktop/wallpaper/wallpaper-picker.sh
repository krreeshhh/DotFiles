#!/usr/bin/env bash
# ==========================================================
# wallpaper-picker.sh - 3D Cover Flow Wallpaper Picker Launcher
# ==========================================================
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# If user explicitly requested rofi fallback via --rofi
if [ "${1:-}" = "--rofi" ]; then
    WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/.wallpaper}"
    CACHE_DIR="${CACHE_DIR:-$HOME/.cache/my-desktop/thumbnails}"
    RASI_THEME="$SCRIPT_DIR/picker.rasi"
    MAP_FILE="/tmp/my_desktop_wallpapers.list"

    python3 "$SCRIPT_DIR/generate-thumbnails.py"

    SELECTED_INDEX=$(python3 -c "
import os, sys, hashlib

WALLPAPER_DIR = os.path.expanduser('$WALLPAPER_DIR')
CACHE_DIR = os.path.expanduser('$CACHE_DIR')
MAP_FILE = '$MAP_FILE'
SUPPORTED = ('.jpg', '.jpeg', '.png', '.webp')

files = []
for root, _, filenames in os.walk(WALLPAPER_DIR):
    for f in sorted(filenames):
        if f.lower().endswith(SUPPORTED):
            files.append(os.path.join(root, f))

files.sort()

if not files:
    sys.exit(2)

with open(MAP_FILE, 'w') as mf:
    for f in files:
        mf.write(f + '\n')
        h = hashlib.md5(f.encode('utf-8')).hexdigest()
        thumb = os.path.join(CACHE_DIR, f'{h}.png')
        base = os.path.splitext(os.path.basename(f))[0]
        sys.stdout.write(f'{base}\0icon\x1f{thumb}\n')
" | rofi -dmenu \
    -i \
    -show-icons \
    -p "󰸉  Wallpapers" \
    -theme "$RASI_THEME" \
    -format i || true)

    if [ -n "$SELECTED_INDEX" ] && [ "$SELECTED_INDEX" -ge 0 ] 2>/dev/null; then
        LINE_NUM=$((SELECTED_INDEX + 1))
        SELECTED_WALLPAPER=$(sed -n "${LINE_NUM}p" "$MAP_FILE" || true)
        if [ -n "$SELECTED_WALLPAPER" ] && [ -f "$SELECTED_WALLPAPER" ]; then
            bash "$SCRIPT_DIR/apply-wallpaper.sh" "$SELECTED_WALLPAPER"
        fi
    fi
    exit 0
fi

# Launch 3D Card Carousel Wallpaper Switcher
exec python3 "$SCRIPT_DIR/carousel-picker.py"
