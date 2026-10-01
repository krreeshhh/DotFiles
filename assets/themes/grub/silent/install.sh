#!/usr/bin/env bash
# ==============================================================================
# SilentGRUB Installer Script
# Installs SilentGRUB theme and configures GRUB to list only actual system bootloaders.
# ==============================================================================
set -e

green='\033[0;32m'
red='\033[0;31m'
cyan='\033[0;36m'
grey='\033[2;37m'
yellow='\033[1;33m'
reset='\033[0m'

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
THEME_DEST="/boot/grub/themes/silent"

echo -e "${cyan}========================================${reset}"
echo -e "${cyan}       SilentGRUB Theme Installer       ${reset}"
echo -e "${cyan}========================================${reset}\n"

# 1. Regenerate assets if needed
echo -e "${grey}Generating theme pixmaps and background...${reset}"
python3 "${SCRIPT_DIR}/generate_assets.py"

# 2. Copy theme files to /boot/grub/themes/silent/
echo -e "${grey}Copying theme to '${THEME_DEST}'...${reset}"
sudo mkdir -p "${THEME_DEST}"
sudo cp -rf "${SCRIPT_DIR}"/* "${THEME_DEST}/"

# 3. Update /etc/default/grub configuration
echo -e "${grey}Updating /etc/default/grub configuration...${reset}"
if [ -f /etc/default/grub ]; then
    sudo cp -f /etc/default/grub /etc/default/grub.bak
    echo -e "${green}Backup saved to /etc/default/grub.bak${reset}"

    # Set GRUB_THEME
    if grep -q '^GRUB_THEME=' /etc/default/grub; then
        sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/silent/theme.txt"|' /etc/default/grub
    elif grep -q '^#GRUB_THEME=' /etc/default/grub; then
        sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/silent/theme.txt"|' /etc/default/grub
    else
        echo 'GRUB_THEME="/boot/grub/themes/silent/theme.txt"' | sudo tee -a /etc/default/grub
    fi

    # Set GRUB_GFXMODE to 1920x1080,auto
    if grep -q '^GRUB_GFXMODE=' /etc/default/grub; then
        sudo sed -i 's|^GRUB_GFXMODE=.*|GRUB_GFXMODE="1920x1080,auto"|' /etc/default/grub
    else
        echo 'GRUB_GFXMODE="1920x1080,auto"' | sudo tee -a /etc/default/grub
    fi

    # Disable unwanted EFI BootNext entries (PXE, HTTP, Removable, DVD, stale NVRAM)
    if grep -q '^GRUB_DISABLE_BOOTNEXT=' /etc/default/grub; then
        sudo sed -i 's|^GRUB_DISABLE_BOOTNEXT=.*|GRUB_DISABLE_BOOTNEXT=true|' /etc/default/grub
    else
        echo 'GRUB_DISABLE_BOOTNEXT=true' | sudo tee -a /etc/default/grub
    fi

    # Disable submenus (flat clean bootloader list)
    if grep -q '^GRUB_DISABLE_SUBMENU=' /etc/default/grub; then
        sudo sed -i 's|^GRUB_DISABLE_SUBMENU=.*|GRUB_DISABLE_SUBMENU=y|' /etc/default/grub
    elif grep -q '^#GRUB_DISABLE_SUBMENU=' /etc/default/grub; then
        sudo sed -i 's|^#GRUB_DISABLE_SUBMENU=.*|GRUB_DISABLE_SUBMENU=y|' /etc/default/grub
    else
        echo 'GRUB_DISABLE_SUBMENU=y' | sudo tee -a /etc/default/grub
    fi
fi

# 4. Rebuild GRUB config
echo -e "${grey}Regenerating /boot/grub/grub.cfg...${reset}"
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n${green}✓ SilentGRUB successfully installed and active!${reset}"
