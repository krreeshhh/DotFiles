# Silent Wallpaper SDDM Theme

A minimalist, modern SDDM theme featuring dynamic wallpaper changing from `~/.wallpaper`, smooth lock-to-login blur transitions, and sleek login controls.

## Features

- **Dynamic Wallpaper Cycling / Randomizer**: Automatically selects a random wallpaper from `/home/Krish/.wallpaper` on start or at configured intervals.
- **Blur Animations**: Smooth animated blur transition (from lock screen blur 0 to login screen blur 32) and zoom/fade effects.
- **Minimalist Login UI**: Clean user avatar, password input, login button, session picker, layout selector, power controls, and virtual keyboard support.
- **Bundled Fonts**: Red Hat Display typography included.

## Structure

- `Main.qml`: Main entry point with wallpaper folder loader and state animations.
- `configs/default.conf`: Active theme configuration (login buttons, animations, wallpaper directory).
- `components/`: QML UI components (Avatar, LoginScreen, LockScreen, PowerMenu, SessionSelector, etc.).
- `fonts/`: Red Hat font families.
- `icons/`: Clean SVG icons for UI actions and desktop sessions.
- `backgrounds/`: Custom background directory (optional).
- `test.sh`: Script to test the theme locally in test mode using `sddm-greeter-qt6`.
- `install.sh`: Script to deploy the theme to `/usr/share/sddm/themes/silent`.

## Testing

```bash
./test.sh
```

## Configuration

Settings are configured in `configs/default.conf`:

```ini
[General]
enable-animations = true
random-wallpaper = true
wallpaper-dir = "/home/Krish/.wallpaper"
wallpaper-interval = 0

[LockScreen]
blur = 0

[LoginScreen]
blur = 32
```
