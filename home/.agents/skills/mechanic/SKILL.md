---
name: mechanic
description: "Master system mechanic for Arch Linux, Hyprland, Quickshell, crash diagnosis, and Material You theming. Use when the user invokes /mechanic, $mechanic, or requests system tuning, repairs, or maintenance."
---

# System Mechanic Skill (`/mechanic`)

This skill acts as the master orchestrator for system maintenance, desktop repair, crash diagnostics, automated command execution, and desktop customization.

## 1. Autonomous Command Execution Protocol
When the `/mechanic` skill is active:
- **Proactively Run Commands**: Directly execute diagnostic, inspection, repair, package management, and configuration commands using your tools. Do not output raw commands asking the user to copy-paste them unless explicitly requested.
- **Root / Sudo Execution**: When tasks require elevated privileges (e.g., `pacman`, `systemctl`, `journalctl`, `/etc/` edits):
  - Always execute using `sudo -A` with the dedicated graphical askpass helper:
    ```bash
    SUDO_ASKPASS=/home/Krish/.local/bin/mechanic-askpass sudo -A <command>
    ```
  - This automatically presents the **Quickshell Material You Authentication Screen** (`AuthDialog.qml`) directly to the user to enter their administrator password.
  - Sudo will cache the credentials for the session, allowing subsequent maintenance steps to proceed autonomously.

## 2. Master Capabilities & Sub-Skills
Orchestrate the 4 core domains as needed:
1. **`diagnose-crash`**: Inspect and resolve application crashes and core dumps from `systemd-coredump` / `coredumpctl`.
2. **`quickshell-dev`**: Create, edit, and debug Quickshell QML widgets, status bars, and layer-shell popups (`~/.config/quickshell/`).
3. **`hyprland-config`**: Configure Hyprland window rules, keybindings, animations, and monitor arrangements safely (`~/.config/hypr/`).
4. **`theme-manager`**: Extract and synchronize Material You color palettes and dynamic glass themes.

## 3. Operational Guidelines & Safety
- **Non-Destructive Verification**: Always verify changes with test commands (`quickshell log`, `quickshell ipc show`, `hyprctl reload`, `coredumpctl list`).
- **Aesthetic Preservation**: Preserve 100% of the user's custom glass UI styling, Material You dynamic colors, and curved corner fillets.
- **Clean Fallbacks**: If Quickshell is ever stopped, `mechanic-askpass` automatically falls back to Rofi password mode to ensure uninterrupted operation.
