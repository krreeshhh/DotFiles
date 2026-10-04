# File Classification Index

Every file exported in this repository is classified into one of the following categories:
- **CORE:** Required for Hyprland compositor, Quickshell, theming engine, basic desktop UI to function.
- **OPTIONAL:** Secondary applications, alternative tools, or personal workflows.
- **HARDWARE-SPECIFIC:** Tied to the NVIDIA RTX 2050 GPU, laptop display, or specific ASUS hardware.
- **GENERATED:** Dynamically created/updated by `generate-theme.py` or runtime scripts.
- **ASSET:** Media files, wallpapers, or greeter themes.
- **PERSONAL:** Default app associations, browser preferences, or user configs.

| File Path | Classification | Description |
| :--- | :--- | :--- |
| `config/hypr/hyprland.lua` | CORE / HARDWARE-SPECIFIC (Partial) | Primary Lua configuration for Hyprland compositor |
| `config/hypr/hyprland.conf` | CORE | Synchronized Hyprland configuration |
| `config/hypr/scripts/autostart.py` | CORE | XDG Autostart script executor |
| `config/hypr/scripts/screenshot.sh` | CORE | Screenshot utility with interactive notification |
| `config/hypr/scripts/caffeine.sh` | CORE | Idle/sleep inhibitor tool |
| `config/quickshell/shell.qml` | CORE | Quickshell main root entrypoint & IPC router |
| `config/quickshell/Theme.qml` | CORE / GENERATED | Quickshell Material You color singleton |
| `config/quickshell/launch.sh` | CORE | Quickshell startup script |
| `config/quickshell/switch.sh` | CORE | Waybar/Quickshell toggle and rollback switcher |
| `config/quickshell/bar/*` (7 files) | CORE | Topbar modules (Workspaces, Clock, Status, Tray, MiniPlayer) |
| `config/quickshell/popups/*` (4 files) | CORE | Popups (ControlCenter, WifiMenu, BluetoothMenu, AppLauncher) |
| `config/my-desktop/theme/generate-theme.py` | CORE | Dynamic Material You palette extractor |
| `config/my-desktop/theme/apply-theme.sh` | CORE | Live theme hot-reloader for compositor and UI |
| `config/my-desktop/theme/colors.*` | GENERATED | Generated palette exports (JSON, Lua, CSS, Conf, Rasi) |
| `config/my-desktop/wallpaper/apply-wallpaper.sh` | CORE | Animated wallpaper engine caller |
| `config/my-desktop/wallpaper/carousel-picker.py` | CORE | 3D cover-flow wallpaper picker (GTK Layer Shell) |
| `config/my-desktop/wallpaper/wallpaper-picker.sh`| CORE | Wrapper script for carousel picker |
| `config/my-desktop/wallpaper/generate-thumbnails.py` | CORE | Thumbnail cache generator |
| `config/my-desktop/wallpaper/config.env` | CORE / HARDWARE-SPECIFIC (144Hz) | Wallpaper backend and transition settings |
| `config/my-desktop/wallpaper/current` | GENERATED | Active wallpaper pointer file |
| `config/my-desktop/launcher/launcher.sh` | CORE | Application launcher toggle script |
| `config/my-desktop/launcher/launcher.py` | CORE | Material You Rofi launcher with categories |
| `config/my-desktop/launcher/webapp_manager.py` | CORE | Web application desktop entry generator |
| `config/my-desktop/launcher/launcher.rasi` | CORE | Rofi launcher styling |
| `config/dunst/dunstrc` | CORE / GENERATED | Dunst notification daemon layout & dynamic colors |
| `config/ghostty/config` | CORE | Ghostty terminal configuration (glass opacity 0.72) |
| `config/ghostty/gtk.css` | GENERATED | Ghostty dialog and window CSS styling |
| `config/clipse/config.json` | CORE | Clipse clipboard manager settings |
| `config/clipse/custom_theme.json` | GENERATED | Clipse clipboard Material You theme |
| `config/nwg-bar/bar.json` | CORE | Power and logout action buttons |
| `config/nwg-bar/style.css` | CORE | Nwg-bar styling |
| `config/waybar/config.jsonc` | OPTIONAL | Alternative Waybar bar configuration |
| `config/waybar/style.css` | OPTIONAL / GENERATED | Alternative Waybar styling |
| `config/waybar/scripts/*` (8 scripts) | OPTIONAL | Waybar interactive popups (Wi-Fi, BT, Quick Settings) |
| `config/gtk-3.0/settings.ini` | CORE | GTK3 theme and cursor settings |
| `config/gtk-3.0/gtk.css` | GENERATED | GTK3 high-contrast dynamic text color overrides |
| `config/gtk-4.0/settings.ini` | CORE | GTK4 theme and cursor settings |
| `config/gtk-4.0/gtk.css` | GENERATED | GTK4 high-contrast dynamic text color overrides |
| `config/environment.d/theme.conf` | CORE | Systemd user environment configuration |
| `config/dolphinrc` | CORE / PERSONAL | Dolphin file manager compact toolbar & theme |
| `config/kdeglobals` | GENERATED | KDE global color palette |
| `config/mimeapps.list` | PERSONAL / OPTIONAL | Default file format and URI associations |
| `config/yazi/theme.toml` | GENERATED | Yazi terminal file manager theme |
| `assets/wallpapers/WALLPAPER_MANIFEST.txt` | ASSET | List of 25 wallpaper filenames |
| `assets/themes/sddm/hyprland-sddm/*` | ASSET | SDDM Greeter dynamic wallpaper theme files |
| `system/etc/sddm.conf.d/hyprland-sddm.conf` | CORE | Directs SDDM to load hyprland-sddm |
| `system/etc/sddm.conf.d/theme.conf` | CORE | Directs SDDM to load hyprland-sddm |
| `system/etc/modprobe.d/nvidia.conf` | CORE / HARDWARE | Configures NVIDIA driver S0ix power management and VRAM allocation preservation |
| `system/etc/systemd/logind.conf.d/lid.conf` | CORE | Configures systemd-logind to trigger suspend on laptop lid switch |
| `system/usr/lib/systemd/system-sleep/hyprland-suspend` | CORE | Freezes and resumes Hyprland rendering around GPU sleep transitions |
| `system/etc/environment` | HARDWARE-SPECIFIC (NVIDIA) | `LIBVA_DRIVER_NAME=nvidia` |
