---
name: hyprland-config
description: Configure and customize Hyprland tiling window manager, window rules, keybindings, animations, monitors, and workspaces.
---

# Hyprland Configuration Skill

This skill guides the agent in safely managing, tuning, and troubleshooting the **Hyprland Wayland Compositor** (`~/.config/hypr/hyprland.conf`).

## Hyprland Architecture & Key Locations
- **Main Config:** `~/.config/hypr/hyprland.conf`
- **Quickshell Layer Rules:** Rules ensuring Quickshell popups blur and layer properly without visual artifacts.
- **Control Interface:** `hyprctl` CLI (`hyprctl reload`, `hyprctl monitors`, `hyprctl clients`, `hyprctl dispatch`).

---

## Guidelines for Modifying Hyprland

### 1. Keybinding Conventions
- Main Modifier: `SUPER` (Windows key).
- Navigation: `SUPER + [H/J/K/L]` or arrow keys.
- Workspaces: `SUPER + [1-9]`, move to workspace: `SUPER + SHIFT + [1-9]`.
- Floating Toggle: `SUPER + V` or `SUPER + SPACE`.

### 2. Window Rules & Layer Rules
When adding application-specific behaviors:
```conf
# Floating window for Picture-in-Picture or modals
windowrulev2 = float, title:^(Picture-in-Picture)$
windowrulev2 = pin, title:^(Picture-in-Picture)$

# Quickshell and Notification Blurs
layerrule = blur, quickshell
layerrule = ignorezero, quickshell
layerrule = blur, dunst
```

### 3. Safe Reloading & Validation
Never kill the compositor process. After editing `hyprland.conf`:
```bash
# Reload configuration safely
hyprctl reload

# Inspect active monitors and workspace layout
hyprctl monitors
hyprctl workspaces
```
