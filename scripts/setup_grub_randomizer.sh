#!/usr/bin/env bash
# ==============================================================================
# setup_grub_randomizer.sh
# Configures GRUB wallpaper randomizer systemd service, sudoers rule, and login hooks
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RANDOMIZER_SCRIPT="$SCRIPT_DIR/grub-wallpaper-randomizer.py"
BIN_TARGET="/usr/local/bin/update-grub-wallpaper"
SERVICE_FILE="/etc/systemd/system/grub-wallpaper-randomizer.service"
SUDOERS_FILE="/etc/sudoers.d/grub-wallpaper"

echo "=== Installing GRUB Wallpaper Randomizer ==="

if [ "$EUID" -ne 0 ]; then
    echo "Elevating privileges with sudo..."
    exec sudo bash "$0" "$@"
fi

# 1. Install binary executable
echo "-> Installing binary to $BIN_TARGET..."
install -m 755 "$RANDOMIZER_SCRIPT" "$BIN_TARGET"

# 2. Configure passwordless sudo for update-grub-wallpaper
echo "-> Configuring passwordless execution in $SUDOERS_FILE..."
cat << 'EOF' > "$SUDOERS_FILE"
Krish ALL=(ALL) NOPASSWD: /usr/local/bin/update-grub-wallpaper, /usr/bin/cp /tmp/grub_random_bg.png /boot/grub/themes/qylock-sword/background.png
EOF
chmod 440 "$SUDOERS_FILE"

# 3. Create systemd service for boot & shutdown transitions
echo "-> Creating systemd service: $SERVICE_FILE..."
cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=GRUB Wallpaper Randomizer
DefaultDependencies=no
After=local-fs.target
Before=shutdown.target reboot.target sddm.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/update-grub-wallpaper --quiet
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target shutdown.target reboot.target
EOF

systemctl daemon-reload
systemctl enable grub-wallpaper-randomizer.service

# 4. Trigger first wallpaper generation
echo "-> Generating initial randomized GRUB background..."
/usr/local/bin/update-grub-wallpaper

echo "✓ GRUB Wallpaper Randomizer installed and activated successfully!"
