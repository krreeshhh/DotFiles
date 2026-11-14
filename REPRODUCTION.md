# Reproduction Guide: Recreating This Exact Machine

This guide describes the complete, exact blueprint required to recreate this customized Arch Linux + Hyprland setup on a clean installation.

---

## What is Included in this Dotfiles Repository
1. **Compositor:** Hyprland v0.57.2 configured with native Lua (`hyprland.lua`), fallback config (`hyprland.conf`), and Picture-in-Picture window management (`pip.lua`).
2. **Desktop Shell:** Quickshell Dotfiles shell (a fork of upstream dots-hyprland, GPL-3.0) - top bar with pill workspace pager, right sidebar (uptime, quick toggles, notification centre, calendar/To-Do/Timer), MPRIS media ring, OSD popups for volume/brightness, and `SUPER + ESC` session menu. The legacy app launcher (with webapp manager) runs as a separate default-config Quickshell instance.
3. **Dynamic Live Theming:** Material You palette extractor (`generate-theme.py`) and live applicator (`apply-theme.sh`) syncing wallpaper colors across Hyprland borders, GTK, Ghostty, Clipse, Dunst, and Yazi; plus `matugen` + a Python `materialyoucolor` venv regenerating the Dotfiles shell palette (`~/.local/state/quickshell/.venv`).
4. **Wallpaper Engine:** 3D Card Carousel / Cover Flow switcher (`carousel-picker.py`) with 144Hz VSync, powered by `awww` / `awww-daemon`.
5. **Launchers & Providers:** Quickshell QML AppLauncher, custom Python WebApp manager (`webapp_manager.py`).
6. **Clipboard & Terminals:** Clipse daemon with pinned floating window rules, Ghostty GPU terminal (glass opacity 0.20), and Yazi terminal file manager.
7. **Audio / Display Controls:** `brightness.sh` and `volume.sh` hardware handlers integrated with the NotificationPopup/OSD services of the Dotfiles shell (with legacy fallbacks).
8. **Look & Theming:** WhiteSur-dark icons, Bibata-Modern-Ice cursor (24px), Adwaita theme with dynamic text contrast CSS, and SDDM theme `R1999_1`.
9. **ASUS TUF Keyboard Lighting:** Armoury Crate GUI (`asus-tuf-aura` / `armoury-crate`), rootless sysfs udev rule, systemd user restore service, and dynamic Material You wallpaper sync hook.

---

## Step-by-Step Recreation Commands

```bash
# 1. Update and install base toolchain, LTS kernel and NVIDIA drivers
sudo pacman -Syu --needed \
  base base-devel linux-lts linux-lts-headers linux-firmware amd-ucode dkms git efibootmgr grub \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver

# 2. Configure 8GB system swap space
sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep -q "^/swapfile" /etc/fstab || echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab

# 3. Configure NVIDIA kernel parameters and environment
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
echo -e 'GRUB_DISABLE_BOOTNEXT="true"\nGRUB_DISABLE_OS_PROBER="true"\nGRUB_DISABLE_SUBMENU="y"' | sudo tee -a /etc/default/grub
[ -f /etc/grub.d/31_efi_bootnext ] && sudo chmod -x /etc/grub.d/31_efi_bootnext
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
echo -e "LIBVA_DRIVER_NAME=nvidia\nMOZ_DISABLE_RDD_SANDBOX=1" | sudo tee -a /etc/environment

# 4. Install core packages from package manifests
sudo pacman -S --needed - < packages/pacman-runtime.txt
sudo pacman -S --needed - < packages/fonts.txt

# 5. Install yay AUR helper
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm

# 6. Install AUR runtime packages (Cursor, Icons, Herdr, fonts)
yay -S --needed --noconfirm - < packages/aur-runtime.txt

# 6b. Create the Dotfiles shell Python venv (pillow + materialyoucolor)
python3 -m venv ~/.local/state/quickshell/.venv
~/.local/state/quickshell/.venv/bin/pip install --upgrade pip
~/.local/state/quickshell/.venv/bin/pip install pillow materialyoucolor

# 7. Enable system and user services
sudo systemctl enable sddm.service NetworkManager.service bluetooth.service ntpd.service
systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service hypr-pip-helper.service quickshell.service asus-tuf-aura-restore.service

# 8. Deploy configurations & binaries
mkdir -p ~/.config ~/.local/bin ~/.local/lib ~/.local/share/asus-tuf-aura ~/.wallpaper ~/Pictures/Screenshots
cp -r config/* ~/.config/
cp -r bin/* ~/.local/bin/
cp -r lib/* ~/.local/lib/ 2>/dev/null || true
cp -r assets/share/asus-tuf-aura/* ~/.local/share/asus-tuf-aura/ 2>/dev/null || true
cp home/.bashrc ~/.bashrc
cp home/.bash_profile ~/.bash_profile
chmod +x ~/.local/bin/*
chmod +x ~/.config/hypr/scripts/* ~/.config/DotFiles/wallpaper/* ~/.config/DotFiles/theme/* ~/.config/DotFiles/launcher/* ~/.config/quickshell/*.sh ~/.config/quickshell/scripts/*

# Ensure symlinks exist
ln -sf ~/.local/bin/awww ~/.local/bin/swww
ln -sf ~/.local/bin/awww-daemon ~/.local/bin/swww-daemon
ln -sf ~/.local/bin/asus-tuf-aura ~/.local/bin/armoury-crate
ln -sf ~/.config/quickshell/qs/Commons ~/.config/quickshell/Commons
ln -sf ~/.config/quickshell/qs/Ui ~/.config/quickshell/Ui

# 9. Deploy SDDM Theme & System Power Management Configs
sudo mkdir -p /usr/share/sddm/themes/hyprland-sddm /etc/sddm.conf.d /etc/systemd/logind.conf.d /etc/modprobe.d /usr/lib/systemd/system-sleep /etc/udev/rules.d
sudo cp -r assets/themes/sddm/hyprland-sddm/* /usr/share/sddm/themes/hyprland-sddm/
sudo cp system/etc/sddm.conf.d/hyprland-sddm.conf /etc/sddm.conf.d/hyprland-sddm.conf
sudo cp system/etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf
sudo cp system/etc/systemd/logind.conf.d/lid.conf /etc/systemd/logind.conf.d/lid.conf
sudo cp system/etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf
sudo cp system/usr/lib/systemd/system-sleep/hyprland-suspend /usr/lib/systemd/system-sleep/hyprland-suspend
sudo cp system/etc/udev/rules.d/99-asus-kbd-backlight.rules /etc/udev/rules.d/99-asus-kbd-backlight.rules
sudo cp system/etc/udev/rules.d/99-rtl8852bu-autosuspend.rules /etc/udev/rules.d/99-rtl8852bu-autosuspend.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=leds && sudo udevadm trigger --subsystem-match=usb
sudo chmod +x /usr/lib/systemd/system-sleep/hyprland-suspend

# 10. Configure GTK & Cursor GSettings
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# 11. Place a wallpaper into ~/.wallpaper/ and initialize the theme engine
bash ~/.config/DotFiles/wallpaper/apply-wallpaper.sh ~/.wallpaper/Reze.png
```
