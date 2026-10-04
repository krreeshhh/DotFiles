# Exact Installation Order for Reproduction

Follow this exact dependency order when rebuilding the desktop environment from a fresh minimal Arch Linux installation:

## 1. Base System, Kernel & Build Toolchain
* Install standard Arch Linux base packages: `base`, `base-devel`, `linux-lts`, `linux-lts-headers`, `linux-firmware`, `amd-ucode`, `dkms`, `git`, `efibootmgr`, `grub`.

## 2. GPU Driver & Power Management Configuration
* Install NVIDIA kernel modules: `nvidia-open-dkms`, `nvidia-utils`, `libva-nvidia-driver`.
* Add `nvidia.NVreg_PreserveVideoMemoryAllocations=1` to GRUB kernel command line in `/etc/default/grub`.
* Regenerate GRUB config (`grub-mkconfig -o /boot/grub/grub.cfg`).
* Enable system services: `nvidia-suspend.service`, `nvidia-hibernate.service`, `nvidia-resume.service`.
* Deploy `/etc/environment` (`LIBVA_DRIVER_NAME=nvidia`, `MOZ_DISABLE_RDD_SANDBOX=1`).

## 3. Core Wayland & Desktop Compositor Packages
* Install native packages from `packages/pacman-runtime.txt`:
  * Compositor: `hyprland`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `polkit-gnome`, `wl-clipboard`, `grim`, `slurp`, `swaybg`, `brightnessctl`.
  * Desktop Shell & Notification: `quickshell`, `waybar`, `nwg-bar`, `dunst`, `rofi`.
  * Terminal & Multiplexer: `ghostty`, `tmux`.
  * Audio Server & Utilities: `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`, `pavucontrol`, `pamixer`, `playerctl`.
  * Network & Bluetooth: `networkmanager`, `network-manager-applet`, `bluez`, `bluez-utils`, `blueman`.
  * Theming & Script Engines: `adwaita-icon-theme`, `gnome-themes-extra`, `dconf`, `sddm`, `python-pillow`, `python-gobject`, `python-cairo`, `gtk-layer-shell`, `cairo`.
  * Fonts: `ttf-jetbrains-mono-nerd`, `adwaita-fonts`, `noto-fonts`, `noto-fonts-emoji`, `terminus-font`.

## 4. AUR Helper & AUR Runtime Packages
* Install `yay-bin` (or `yay`).
* Install packages from `packages/aur-runtime.txt`:
  * Cursor: `bibata-cursor-theme`.
  * Icons: `whitesur-icon-theme`.
  * Terminal Workspace: `herdr-bin`.

## 5. Enable System & User Daemons
* System level:
  ```bash
  sudo systemctl enable sddm.service NetworkManager.service bluetooth.service ntpd.service
  ```
* User level (as normal user):
  ```bash
  systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service
  ```

## 6. Deploy Standalone Binaries & Libraries
* Copy `bin/*` to `~/.local/bin/` and ensure executable permissions (`chmod +x ~/.local/bin/*`).
* Create compatibility symlinks:
  ```bash
  ln -sf ~/.local/bin/awww ~/.local/bin/swww
  ln -sf ~/.local/bin/awww-daemon ~/.local/bin/swww-daemon
  ```
* Copy `lib/*` to `~/.local/lib/` if using `strata`.

## 7. Deploy Configuration Files
* Deploy directories from `config/` to `~/.config/`:
  * `hypr/`, `quickshell/`, `waybar/`, `dunst/`, `nwg-bar/`, `my-desktop/`, `ghostty/`, `yazi/`, `clipse/`, `gtk-3.0/`, `gtk-4.0/`, `environment.d/`, `systemd/user/`.
* Deploy individual files: `dolphinrc`, `kdeglobals`, `mimeapps.list`, `gtkrc-2.0` to `~/.config/` and `~/.gtkrc-2.0`.
* Deploy `home/.bashrc` and `home/.bash_profile` to `~/`.
* Set script execution permissions:
  ```bash
  chmod +x ~/.config/hypr/scripts/* ~/.config/my-desktop/wallpaper/* ~/.config/my-desktop/theme/* ~/.config/my-desktop/launcher/* ~/.config/quickshell/*.sh ~/.config/waybar/*.sh
  ```

## 8. Deploy Assets & Display Manager Themes
* Copy SDDM theme `assets/themes/sddm/hyprland-sddm` to `/usr/share/sddm/themes/hyprland-sddm/`.
* Deploy `/etc/sddm.conf.d/theme.conf` and `/etc/sddm.conf.d/hyprland-sddm.conf` pointing to `hyprland-sddm`.
* Deploy `/etc/systemd/logind.conf.d/lid.conf` to configure lid close DPMS power handling.
* Populate `~/.wallpaper/` with wallpapers (see `assets/wallpapers/WALLPAPER_MANIFEST.txt`).

## 9. Initialize GSettings & Theme Generator
* Apply GTK and Cursor preferences via gsettings:
  ```bash
  gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
  gsettings set org.gnome.desktop.interface icon-theme Adwaita
  gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice
  gsettings set org.gnome.desktop.interface cursor-size 24
  gsettings set org.gnome.desktop.interface font-name Adwaita
