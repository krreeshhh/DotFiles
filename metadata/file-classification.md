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
| `config/quickshell/shell.qml` | CORE | Launcher/auth host: previous AppLauncher + AuthDialog/PromptDialog (`shell` IPC) |
| `config/quickshell/Theme.qml` | CORE / GENERATED | Quickshell Material You color singleton (extended with Dotfiles layer tokens) |
| `config/quickshell/dotfiles/*` | CORE | Dotfiles shell (fork of upstream dots-hyprland, GPL-3.0): top bar, right sidebar, overview, session screen, OSD, notifications, settings and welcome apps |
| `config/quickshell/dotfiles/panelFamilies/DotfilesFamily.qml` | CORE | Family loader (bar, right sidebar, session screen, polkit disabled, wallpaper selector disabled) |
| `config/quickshell/dotfiles/modules/dotfiles/background/*` | CORE | Wallpaper, cookie clock, parallax workspace backgrounds |
| `config/quickshell/dotfiles/modules/dotfiles/bar/*` | CORE | Top bar (resources, media ring, workspaces, clock, tray, indicators) |
| `config/quickshell/dotfiles/modules/dotfiles/sidebarRight/*` | CORE | Right sidebar (uptime, quick sliders, quick toggles, notifications, calendar/To-Do/Timer, dialogs) |
| `config/quickshell/dotfiles/modules/dotfiles/overview/*` | CORE | Search palette (prefixes: `/` actions, `>` apps, `;` clipboard, `:` emoji, `=` math, `$` shell, `?` web) |
| `config/quickshell/dotfiles/modules/dotfiles/sessionScreen/*` | CORE | Session menu (lock/sleep/logout/task manager/hibernate/shutdown/reboot/firmware) |
| `config/quickshell/dotfiles/modules/dotfiles/onScreenDisplay/*` | CORE | Volume/brightness OSD |
| `config/quickshell/dotfiles/modules/dotfiles/notificationPopup/*` | CORE | Top-right notification popups |
| `config/quickshell/dotfiles/services/*` | CORE | Singleton services (Audio, Network, BluetoothStatus, Battery, MprisController, Notifications, ResourceUsage, Brightness, Weather, ...) |
| `config/quickshell/dotfiles/settings.qml` | CORE | Dotfiles Settings app |
| `config/quickshell/dotfiles/welcome.qml` | CORE | Dotfiles first-run welcome app |
| `config/quickshell/dotfiles/LICENSE-GPL-3.0` | CORE | Upstream license (GPL-3.0), required by upstream dots-hyprland |
| `config/matugen/*` | CORE | Matugen templates & config used by Dotfiles shell theming |
| `config/dotfiles/config.json` | DYNAMIC / PERSONAL | Dotfiles shell config (bar position, transparency, palette type, wallpaper path) |
| `config/quickshell/Theme.qml` | CORE / GENERATED | Quickshell Material You color singleton |
| `config/quickshell/launch.sh` | CORE | Quickshell startup script |
| `config/quickshell/bar/*` (legacy) | LEGACY | Legacy topbar modules, kept for rollback |
| `config/quickshell/popups/*` (legacy) | CORE / LEGACY | Launcher host (AppLauncher), legacy menus, AuthDialog/PromptDialog for the sudo askpass helper |
| `config/dotfiles/theme/generate-theme.py` | CORE | Dynamic Material You palette extractor |
| `config/dotfiles/theme/apply-theme.sh` | CORE | Live theme hot-reloader for compositor and UI |
| `config/dotfiles/theme/colors.*` | GENERATED | Generated palette exports (JSON, Lua, CSS, Conf, Rasi) |
| `config/dotfiles/wallpaper/apply-wallpaper.sh` | CORE | Animated wallpaper engine caller |
| `config/dotfiles/wallpaper/carousel-picker.py` | CORE | 3D cover-flow wallpaper picker (GTK Layer Shell) |
| `config/dotfiles/wallpaper/wallpaper-picker.sh`| CORE | Wrapper script for carousel picker |
| `config/dotfiles/wallpaper/generate-thumbnails.py` | CORE | Thumbnail cache generator |
| `config/dotfiles/wallpaper/config.env` | CORE / HARDWARE-SPECIFIC (144Hz) | Wallpaper backend and transition settings |
| `config/dotfiles/wallpaper/current` | GENERATED | Active wallpaper pointer file |
| `config/dotfiles/launcher/launcher.sh` | CORE | Application launcher toggle script |
| `config/dotfiles/launcher/launcher.py` | CORE | Material You Rofi launcher with categories |
| `config/dotfiles/launcher/webapp_manager.py` | CORE | Web application desktop entry generator |
| `config/dotfiles/launcher/launcher.rasi` | CORE | Rofi launcher styling |
| `config/dunst/dunstrc` | CORE / GENERATED | Dunst notification daemon layout & dynamic colors |
| `config/ghostty/config` | CORE | Ghostty terminal configuration (glass opacity 0.72) |
| `config/ghostty/gtk.css` | GENERATED | Ghostty dialog and window CSS styling |
| `config/clipse/config.json` | CORE | Clipse clipboard manager settings |
| `config/clipse/custom_theme.json` | GENERATED | Clipse clipboard Material You theme |
| `config/gtk-3.0/settings.ini` | CORE | GTK3 theme and cursor settings |
| `config/gtk-3.0/gtk.css` | GENERATED | GTK3 high-contrast dynamic text color overrides |
| `config/gtk-4.0/settings.ini` | CORE | GTK4 theme and cursor settings |
| `config/gtk-4.0/gtk.css` | GENERATED | GTK4 high-contrast dynamic text color overrides |
| `config/environment.d/theme.conf` | CORE | Systemd user environment configuration |
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
