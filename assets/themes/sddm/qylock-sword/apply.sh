#!/usr/bin/env bash
set -e

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="$(basename "$THEME_DIR")"
TARGET_DIR="/usr/share/sddm/themes/$THEME_NAME"

echo "=== Applying SDDM Theme: $THEME_NAME ==="

if [ "$EUID" -ne 0 ]; then
    echo "Elevating privileges with sudo..."
    exec sudo bash "$0" "$@"
fi

echo "-> Installing theme files to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
cp -r "$THEME_DIR/"* "$TARGET_DIR/"

echo "-> Updating /etc/sddm.conf.d/theme.conf..."
mkdir -p /etc/sddm.conf.d
cat <<EOF > /etc/sddm.conf.d/theme.conf
[Theme]
Current=$THEME_NAME
EOF

echo "✓ Theme $THEME_NAME successfully installed and activated!"
echo "You can test the greeter anytime by running:"
echo "  sddm-greeter-qt6 --test-mode --theme $TARGET_DIR"
