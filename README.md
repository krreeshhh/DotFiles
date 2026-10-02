<div align="center">

# DotFiles

### Arch Linux · Hyprland · Quickshell · Material You

A reproducible, fully-integrated Wayland desktop environment built on Arch Linux. Featuring a modular Quickshell desktop shell, native Lua-configured Hyprland compositor, automated Material You dynamic color scheme generation from wallpapers, and custom helper daemons.

<p align="center">
  <img src="https://img.shields.io/badge/OS-Arch%20Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white" alt="Arch Linux" />
  <img src="https://img.shields.io/badge/Compositor-Hyprland%20(Lua)-00C8FF?style=flat-square&logo=hyprland&logoColor=white" alt="Hyprland" />
  <img src="https://img.shields.io/badge/Shell-Quickshell%20(QML)-333333?style=flat-square" alt="Quickshell" />
  <img src="https://img.shields.io/badge/Palette-Material%20You%20Engine-6A1B9A?style=flat-square" alt="Material You" />
  <img src="https://img.shields.io/badge/Terminal-Ghostty-FF6B6B?style=flat-square" alt="Ghostty" />
</p>

</div>

---

## ⬡ System Architecture & Overview

This setup is built for performance, aesthetics, and deterministic reproduction across fresh Arch installations.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HYPRLAND (LUA API)                            │
│  ┌──────────────────┐  ┌─────────────────────┐  ┌────────────────────┐  │
│  │    QUICKSHELL    │  │    DYNAMIC THEME    │  │   UNIVERSAL PiP    │  │
│  │   Desktop Bar    │  │   Palette Extractor │  │   Helper Daemon    │  │
│  │  Control Center  │  │   Wallpaper Picker  │  │  Browser Extension │  │
│  │   OSD Overlays   │  │   Live Reloader     │  │   Floating Manager │  │
│  └──────────────────┘  └─────────────────────┘  └────────────────────┘  │
│  ┌──────────────────┐  ┌─────────────────────┐  ┌────────────────────┐  │
│  │   APP LAUNCHER   │  │       TERMINAL      │  │    AUDIO & MEDIA   │  │
│  │ Quickshell Native│  │  Ghostty (0.20 op)  │  │ PipeWire / Player  │  │
│  │ WebApps & Plugins│  │  Nautilus / Yazi    │  │ MPRIS Mini Player  │  │
│  └──────────────────┘  └─────────────────────┘  └────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ◈ Core Components

| Layer | Component | Implementation Details |
| :--- | :--- | :--- |
| **Compositor** | Hyprland | Configured with native Lua API (`hyprland.lua`), custom gestures, blur layer rules, and hotkey bindings. |
| **Desktop Shell** | Quickshell | Modular QML bar, workspace pager, network and bluetooth popups, audio OSD, and control center. |
| **Launcher** | Quickshell AppLauncher | Native QML full-screen application launcher with integrated webapps and plugin management. |
| **Theme Engine** | Material You (`my-desktop`) | K-Means palette extractor generating synchronized color schemes across Hyprland, Ghostty, GTK, Dunst, and Quickshell. |
| **Wallpaper Picker** | Custom 3D Carousel | OpenGL and Python wallpaper selector with instant theme regeneration and swww transitions. |
| **Notifications** | Dunst | Minimal notification server synchronized with live palette colors. |
| **Picture-in-Picture**| Hypr-PiP | Background Python daemon + Chromium browser extension for universal floating video pin management. |
| **Terminal** | Ghostty | High-performance GPU-accelerated terminal running at 0.20 background opacity with blur. |
| **File Manager** | Nautilus + Yazi | GTK4 graphical manager (Nautilus) alongside terminal file manager (Yazi). |
| **Clipboard** | Clipse | TUI clipboard manager running with dedicated floating window rules. |
| **Display Manager** | SDDM | Custom `hyprland-sddm` theme with dynamic wallpaper autorefresh and reverse-blur focus. |
| **Bootloader** | GRUB | Minimalist `silent` theme with dynamic wallpaper integration. |

---

## ⚡ Keybindings Cheat Sheet

The default modifier key is `SUPER` (`Mod4`).

### ◇ Window Management

| Shortcut | Action |
| :--- | :--- |
| `SUPER + Q` | Close active window |
| `SUPER + V` | Toggle floating mode |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + P` | Toggle pseudo-tiling mode |
| `SUPER + J` | Toggle split direction |
| `SUPER + H / J / K / L` | Move focus in direction |
| `SUPER + 1 - 9` | Switch to workspace 1 to 9 |
| `SUPER + SHIFT + 1 - 9` | Move active window to workspace 1 to 9 |
| `SUPER + MOUSE_LEFT` | Move window interactively |
| `SUPER + MOUSE_RIGHT` | Resize window interactively |

### ◇ System & Shell Launchers

| Shortcut | Action |
| :--- | :--- |
| `SUPER + RETURN` | Launch Ghostty terminal |
| `SUPER + SPACE` | Toggle Quickshell application launcher |
| `SUPER + C` | Toggle Quickshell control center |
| `SUPER + E` | Open Nautilus file manager |
| `SUPER + B` | Launch default browser |
| `SUPER + ESCAPE` | Open `nwg-bar` power menu |
| `SUPER + V` (Clipboard) | Open Clipse clipboard history |
| `SUPER + SHIFT + S` | Interactive area screenshot (slurp + grim) |
| `SUPER + SHIFT + W` | Open 3D wallpaper carousel picker |

### ◇ Media & Hardware Keys

| Key | Action |
| :--- | :--- |
| `XF86AudioRaiseVolume` / `F8` | Volume +5% (Triggers Quickshell OSD) |
| `XF86AudioLowerVolume` / `F7` | Volume -5% (Triggers Quickshell OSD) |
| `XF86AudioMute` | Toggle audio mute |
| `XF86MonBrightnessUp` | Brightness +5% (Triggers Quickshell OSD) |
| `XF86MonBrightnessDown` | Brightness -5% (Triggers Quickshell OSD) |
| `XF86AudioPlay` / `Pause` | Play / Pause active MPRIS player |
| `XF86AudioNext` / `Prev` | Next / Previous track |

---

## ⚙ Installation & Deployment

### Prerequisites

- A fresh or existing installation of **Arch Linux**.
- An active internet connection.
- A standard non-root user with `sudo` privileges.

### 1. Clone the Repository

```bash
git clone https://github.com/krreeshhh/DotFiles.git ~/Dotfiles
cd ~/Dotfiles
```

### 2. Run the Installer

The installer automatically detects hardware (including NVIDIA GPUs), configures pacman/AUR packages, sets up systemd user units, deploys config trees, installs SDDM and GRUB themes, and initializes the dynamic theme engine.

```bash
# Standard Core Installation (Hyprland + Quickshell + Drivers + UI)
./install.sh --core

# Full Desktop Installation (Core + All Browsers + Media Apps + Dev Tools)
./install.sh --all

# Deploy Config Files Only (Skip package installations)
./install.sh --config-only
```

You can also run `./install.sh` without flags for an interactive CLI menu.

---

## ⟡ Repository File Structure

```text
DotFiles/
├── assets/
│   ├── fonts/               # Custom system fonts (The Last Shuriken, Torus)
│   ├── hypr-pip/            # Chromium extension for Universal Picture-in-Picture
│   ├── share/               # Desktop launcher entries (.desktop) and webapp icons
│   ├── themes/
│   │   └── grub/silent/     # Active minimalist GRUB bootloader theme
│   └── wallpapers/          # Packaged aesthetic wallpaper collection (27 wallpapers)
├── bin/                     # Standalone custom binaries (hypr-pip-helper, clipse, strata)
├── config/
│   ├── clipse/              # Clipboard manager config
│   ├── dunst/               # Notification styling
│   ├── environment.d/       # Session environment variables
│   ├── ghostty/             # Ghostty terminal config
│   ├── gtk-3.0/ & gtk-4.0/  # GTK interface themes and icons
│   ├── hypr/                # Hyprland configuration (hyprland.lua, pip.lua, scripts)
│   ├── my-desktop/          # Material You theme extractor and wallpaper engines
│   ├── nwg-bar/             # Power menu layout
│   ├── quickshell/          # Quickshell modular shell (Bar, OSD, Popups, Plugins)
│   ├── systemd/user/        # Systemd user services (hypr-pip, quickshell, battery-alert)
│   ├── waybar/              # Fallback Waybar configuration
│   └── yazi/                # Terminal file manager configuration
├── packages/                # Explicit package manifests (pacman, AUR, fonts)
├── scripts/                 # System verify test runner and maintenance utilities
├── system/                  # System-level configuration (/etc/sddm.conf.d, etc.)
├── install.sh               # Automated deployment script
├── MANIFEST.md              # Complete catalog of all 392 tracked files
├── REPRODUCTION.md          # Step-by-step fresh install guide
└── INSTALL-ORDER.md         # Deterministic dependency execution order
```

---

## ✦ Verification & Integrity Testing

To verify the integrity of the repository configuration, syntax, and asset trees at any time:

```bash
./scripts/verify.sh
```

This runs a test suite (72 automated checks) covering:
- Directory structures and documentation manifests.
- Pacman and AUR package manifest integrity.
- Hyprland daemon scripts and hotkey bindings.
- Quickshell modular QML plugin trees.
- Shell script syntax verification (`bash -n`) on all `.sh` scripts.
- Python compilation checks (`py_compile`) on all `.py` scripts.
- SDDM and GRUB active theme configurations.
- Wallpaper and font bundle integrity.

---

## License

This configuration is released under the [MIT License](LICENSE).
