---
name: theme-manager
description: Manage desktop theming, Material You dynamic color palettes, wallpaper color extraction, and live shell theme reloads.
---

# Theme Management Skill

This skill guides the agent in managing the desktop's dynamic **Material You / Glass Theme** system.

## Theming Components & Data Flow
1. **Dynamic Color Palette:** Stored in `~/.config/my-desktop/theme/colors.json` (keys: `primary`, `on_primary`, `primary_container`, `secondary`, `background`, `surface`, `surface_variant`, `surface_selected`, `on_surface`, `on_surface_variant`, `outline`, `outline_subtle`, `error`).
2. **Quickshell Theme Singleton:** [`~/.config/quickshell/Theme.qml`](file:///home/Krish/.config/quickshell/Theme.qml) reads `colors.json` via a background python process and binds them to all shell surfaces, glass backgrounds, and fillets.
3. **Live Reload:** Triggered instantly across all running Quickshell windows without restarting the shell:
   ```bash
   quickshell ipc call shell reloadTheme
   ```

---

## Workflow & Operations

### 1. Reading Active Colors
Inspect the currently loaded color tokens:
```bash
cat ~/.config/my-desktop/theme/colors.json | jq .
```

### 2. Updating Color Accents
When generating or adjusting palette colors:
- Maintain readability and contrast between `on_surface` (light text) and `surface` (dark background).
- Ensure `barBackground` and `popupSurface` retain appropriate alpha levels for the glassmorphism effect.

### 3. Triggering Live Theme Propagation
Always invoke the Quickshell theme reload after modifying `colors.json`:
```bash
quickshell ipc call shell reloadTheme
```
