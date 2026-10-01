# SilentGRUB Theme

A modern, minimalist GRUB theme designed to match the **SilentSDDM** aesthetic.

## Features

- **Minimalist Aesthetic**: Clean typography using Red Hat Display and Red Hat Mono fonts.
- **Glassmorphism Design**: Subtle translucent containers, rounded selection pills, and minimalist progress countdown bar.
- **Clean Bootloader List**: Automatically filters out stale/dummy EFI NVRAM entries (PXE, HTTP, network devices, duplicate bootnext items) and eliminates messy submenus.
- **Wallpaper Sync**: Includes a script (`sync_wallpaper.sh`) to easily sync backgrounds from `~/.wallpaper/`.

## Directory Structure

```
SilentGRUB/
├── theme.txt              # Main GRUB theme definition
├── background.png         # Default 1080p background
├── fonts/                 # Converted Red Hat Display/Mono .pf2 fonts
├── icons/                 # Crisp bootloader & system icons (Arch, Windows, Linux, UEFI, etc.)
├── pixmaps/               # 9-slice and 3-slice UI components (select pills, containers, bars)
├── generate_assets.py     # Python script to regenerate pixmaps
├── sync_wallpaper.sh      # Helper to update theme background with an image from ~/.wallpaper
└── install.sh             # One-step installation and GRUB configuration script
```

## Installation

To install the theme and clean up the bootloader list:

```bash
cd /home/Krish/SilentGRUB
sudo ./install.sh
```

## Changing the Background

To update the GRUB background with a random or specific wallpaper from `~/.wallpaper`:

```bash
# Pick a random wallpaper from ~/.wallpaper
./sync_wallpaper.sh

# Or specify a particular image
./sync_wallpaper.sh /home/Krish/.wallpaper/Makima.png
```
