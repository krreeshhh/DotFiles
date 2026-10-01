# Reproduction Guide: Recreating This Exact Machine

This guide describes the complete, exact blueprint required to recreate this customized Arch Linux + Hyprland setup on a clean installation.

---

## What is Included in this Dotfiles Repository
1. **Compositor:** Hyprland v0.56.2 configured with native Lua (`hyprland.lua`), fallback config (`hyprland.conf`), and Picture-in-Picture window management (`pip.lua`).
2. **Desktop Shell:** Quickshell custom topbar, pill workspaces, clock, status cluster, sliding system tray drawer, MPRIS mini player, on-screen display (OSD) popups for volume/brightness/mic, and slide-in popups for Control Center, Wi-Fi, Bluetooth, and AppLauncher.
3. **Alternative Bar:** Waybar complete setup with Python-backed custom popup menus and toggle switch script (`switch.sh`).
4. **Dynamic Live Theming:** Material You palette extractor (`generate-theme.py`) and live applicator (`apply-theme.sh`) syncing wallpaper colors across Hyprland borders, Quickshell, Waybar, Dunst, Walker, Ghostty, GTK, Clipse, and Yazi.
5. **Wallpaper Engine:** 3D Card Carousel / Cover Flow switcher (`carousel-picker.py`) with 144Hz VSync, powered by `awww` / `awww-daemon`.
6. **Launchers & Providers:** Quickshell QML AppLauncher, custom Python WebApp and Plugin managers (`webapp_manager.py`, `plugin_manager.py`), and Walker daemon with Elephant backend.
7. **Clipboard & Terminals:** Clipse daemon with pinned floating window rules, Ghostty GPU terminal (glass opacity 0.20), and Yazi terminal file manager.
8. **Audio / Display Controls:** `brightness.sh` and `volume.sh` hardware handlers integrated with Quickshell native OSD.
9. **Look & Theming:** WhiteSur-dark icons, Bibata-Modern-Ice cursor (24px), Adwaita theme with dynamic text contrast CSS, and SDDM theme `R1999_1`.

---

## Step-by-Step Recreation Commands

```bash
# 1. Update and install base toolchain, LTS kernel and NVIDIA drivers
sudo pacman -Syu --needed \
  base base-devel linux-lts linux-lts-headers linux-firmware amd-ucode dkms git efibootmgr grub \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver

# 2. Configure NVIDIA kernel parameters and environment
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
echo -e "LIBVA_DRIVER_NAME=nvidia\nMOZ_DISABLE_RDD_SANDBOX=1" | sudo tee -a /etc/environment

# 3. Install core packages from package manifests
sudo pacman -S --needed - < packages/pacman-runtime.txt
sudo pacman -S --needed - < packages/fonts.txt

# 4. Install yay AUR helper
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm

# 5. Install AUR runtime packages
yay -S --needed --noconfirm - < packages/aur-runtime.txt

# 6. Enable system and user services
sudo systemctl enable sddm.service NetworkManager.service bluetooth.service ntpd.service
systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service elephant.service hypr-pip-helper.service quickshell.service

# 7. Deploy configurations & binaries
mkdir -p ~/.config ~/.local/bin ~/.local/lib ~/.wallpaper ~/Pictures/Screenshots
cp -r config/* ~/.config/
cp -r bin/* ~/.local/bin/
cp -r lib/* ~/.local/lib/ 2>/dev/null || true
cp home/.bashrc ~/.bashrc
cp home/.bash_profile ~/.bash_profile
chmod +x ~/.local/bin/*
chmod +x ~/.config/hypr/scripts/* ~/.config/my-desktop/wallpaper/* ~/.config/my-desktop/theme/* ~/.config/my-desktop/launcher/* ~/.config/quickshell/*.sh ~/.config/quickshell/scripts/* ~/.config/waybar/*.sh ~/.config/waybar/scripts/*

# Ensure symlinks exist
ln -sf ~/.local/bin/awww ~/.local/bin/swww
ln -sf ~/.local/bin/awww-daemon ~/.local/bin/swww-daemon
ln -sf ~/.local/bin/omarchy-agent ~/.local/bin/agent
ln -sf ~/.config/quickshell/qs/Commons ~/.config/quickshell/Commons
ln -sf ~/.config/quickshell/qs/Ui ~/.config/quickshell/Ui

# 8. Deploy SDDM Theme
sudo mkdir -p /usr/share/sddm/themes/R1999_1 /etc/sddm.conf.d
sudo cp -r assets/themes/sddm/R1999_1/* /usr/share/sddm/themes/R1999_1/
sudo cp system/etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf

# 9. Configure GTK & Cursor GSettings
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# 10. Place a wallpaper into ~/.wallpaper/ and initialize the theme engine
bash ~/.config/my-desktop/wallpaper/apply-wallpaper.sh ~/.wallpaper/Reze.png
```
