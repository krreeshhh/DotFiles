#!/usr/bin/env bash
# Sync a wallpaper from ~/.wallpaper to SilentGRUB theme
set -e

WALL_DIR="${HOME}/.wallpaper"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
THEME_DEST="/boot/grub/themes/silent"

if [ -n "$1" ] && [ -f "$1" ]; then
    CHOSEN_WALL="$1"
elif [ -d "$WALL_DIR" ]; then
    # Pick random or first
    CHOSEN_WALL=$(find "$WALL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | shuf -n 1)
fi

if [ -z "$CHOSEN_WALL" ] || [ ! -f "$CHOSEN_WALL" ]; then
    echo "No wallpaper found in $WALL_DIR"
    exit 1
fi

echo "Setting GRUB background from: $CHOSEN_WALL"
python3 -c "
from PIL import Image
im = Image.open('$CHOSEN_WALL').convert('RGBA')
im = im.resize((1920, 1080), Image.Resampling.LANCZOS)
dark_overlay = Image.new('RGBA', (1920, 1080), (10, 12, 18, 120))
im = Image.alpha_composite(im, dark_overlay)
im.save('$SCRIPT_DIR/background.png', 'PNG')
"

if [ -d "$THEME_DEST" ]; then
    echo "Updating installed theme background in $THEME_DEST..."
    sudo cp -f "$SCRIPT_DIR/background.png" "$THEME_DEST/background.png"
fi

echo "Background updated successfully!"
