# Exact Installation Order for Reproduction

Follow this exact dependency order when rebuilding the desktop environment from a fresh minimal Arch Linux installation:

## 1. Base System, Kernel & Build Toolchain
* Install standard Arch Linux base packages: `base`, `base-devel`, `linux-lts`, `linux-lts-headers`, `linux-firmware`, `amd-ucode`, `dkms`, `git`, `efibootmgr`, `grub`.

## 2. Swap Space Configuration
* Configure an 8GB swapfile at `/swapfile`:
  ```bash
  sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q "^/swapfile" /etc/fstab || echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab
  ```

## 3. GPU Driver & Power Management Configuration
* Install NVIDIA kernel modules: `nvidia-open-dkms`, `nvidia-utils`, `libva-nvidia-driver`.
* Add `nvidia.NVreg_PreserveVideoMemoryAllocations=1` to GRUB kernel command line in `/etc/default/grub`.
* Regenerate GRUB config (`grub-mkconfig -o /boot/grub/grub.cfg`).
* Enable system services: `nvidia-suspend.service`, `nvidia-hibernate.service`, `nvidia-resume.service`.
* Deploy `/etc/environment` (`LIBVA_DRIVER_NAME=nvidia`, `MOZ_DISABLE_RDD_SANDBOX=1`).

## 4. Core Wayland & Desktop Compositor Packages
* Install native packages from `packages/pacman-runtime.txt`:
  * Compositor: `hyprland`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `polkit-gnome`, `wl-clipboard`, `grim`, `slurp`, `swaybg`, `brightnessctl`.
  * Desktop Shell & Notification: `quickshell`, `waybar`, `nwg-bar`, `dunst`, `rofi`.
  * Terminal & Multiplexer: `ghostty`, `tmux`.
  * Audio Server & Utilities: `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`, `pavucontrol`, `pamixer`, `playerctl`.
  * Network & Bluetooth: `networkmanager`, `network-manager-applet`, `bluez`, `bluez-utils`, `blueman`.
  * Theming & Script Engines: `adwaita-icon-theme`, `gnome-themes-extra`, `dconf`, `sddm`, `python-pillow`, `python-gobject`, `python-cairo`, `gtk-layer-shell`, `cairo`.
  * Fonts: `ttf-jetbrains-mono-nerd`, `adwaita-fonts`, `noto-fonts`, `noto-fonts-emoji`, `terminus-font`.

## 5. AUR Helper & AUR Runtime Packages
* Install `yay-bin` (or `yay`).
* Install packages from `packages/aur-runtime.txt`:
  * Cursor: `bibata-cursor-theme`.
  * Icons: `whitesur-icon-theme`.
  * Terminal Workspace: `herdr-bin`.

## 6. Enable System & User Daemons
* System level:
  ```bash
  sudo systemctl enable sddm.service NetworkManager.service bluetooth.service ntpd.service
  ```
* User level (as normal user):
  ```bash
  systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service asus-tuf-aura-restore.service
  ```

## 7. Deploy Standalone Binaries & Libraries
* Copy `bin/*` to `~/.local/bin/` and ensure executable permissions (`chmod +x ~/.local/bin/*`).
* Create compatibility symlinks:
  ```bash
  ln -sf ~/.local/bin/awww ~/.local/bin/swww
  ln -sf ~/.local/bin/awww-daemon ~/.local/bin/swww-daemon
  ln -sf ~/.local/bin/asus-tuf-aura ~/.local/bin/armoury-crate
  ```
* Copy `assets/share/asus-tuf-aura/*` to `~/.local/share/asus-tuf-aura/`.
* Copy `lib/*` to `~/.local/lib/` if using `strata`.

## 8. Deploy Configuration Files
* Deploy directories from `config/` to `~/.config/`:
  * `hypr/`, `quickshell/`, `waybar/`, `dunst/`, `nwg-bar/`, `my-desktop/`, `ghostty/`, `yazi/`, `clipse/`, `gtk-3.0/`, `gtk-4.0/`, `environment.d/`, `systemd/user/`.
* Deploy individual files: `dolphinrc`, `kdeglobals`, `mimeapps.list`, `gtkrc-2.0` to `~/.config/` and `~/.gtkrc-2.0`.
* Deploy `home/.bashrc` and `home/.bash_profile` to `~/`.
* Set script execution permissions:
  ```bash
  chmod +x ~/.config/hypr/scripts/* ~/.config/my-desktop/wallpaper/* ~/.config/my-desktop/theme/* ~/.config/my-desktop/launcher/* ~/.config/quickshell/*.sh ~/.config/waybar/*.sh
  ```

## 9. Deploy Assets, Power Management & Display Manager Themes
* Copy SDDM theme `assets/themes/sddm/hyprland-sddm` to `/usr/share/sddm/themes/hyprland-sddm/`.
* Deploy `/etc/sddm.conf.d/theme.conf` and `/etc/sddm.conf.d/hyprland-sddm.conf` pointing to `hyprland-sddm`.
* Deploy `/etc/modprobe.d/nvidia.conf` for S0ix Modern Standby and VRAM allocation preservation.
* Deploy `/etc/systemd/logind.conf.d/lid.conf` to configure lid close system suspend.
* Deploy `/usr/lib/systemd/system-sleep/hyprland-suspend` to pause/resume Hyprland around GPU sleep.
* Deploy `/etc/udev/rules.d/99-asus-kbd-backlight.rules` for rootless ASUS TUF keyboard backlight access (`sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=leds`).
* Populate `~/.wallpaper/` with wallpapers (see `assets/wallpapers/WALLPAPER_MANIFEST.txt`).

## 10. Initialize GSettings & Theme Generator
* Apply GTK and Cursor preferences via gsettings:
  ```bash
  gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
  gsettings set org.gnome.desktop.interface icon-theme Adwaita
  gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice
  gsettings set org.gnome.desktop.interface cursor-size 24
  gsettings set org.gnome.desktop.interface font-name Adwaita
  ```
