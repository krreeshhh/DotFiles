---
name: quickshell-dev
description: Develop, customize, and debug Quickshell desktop shell components, bar widgets, glass themes, and layer-shell popups.
---

# Quickshell Development Skill

This skill guides the agent in safely authoring, customizing, and debugging QML components for **Quickshell** (`/usr/bin/quickshell`).

## Project Layout (`~/.config/quickshell/`)
- **`shell.qml`**: ShellRoot containing screens, bar instantiation, popup instances, and IPC handlers (`IpcHandler { target: "shell" }`).
- **`Theme.qml`**: Singleton theme managing Material You dynamic colors, glass alphas, and typography (`JetBrainsMono Nerd Font`).
- **`bar/Bar.qml`**: The top status bar (36px high) featuring left/right curved canvas fillets (`leftFillet`, `rightFillet`) and modular rows:
  - *Left:* `Workspaces.qml`, `ChatButton.qml`
  - *Center:* `Clock.qml`
  - *Right:* `LedgeWidget.qml`, `MiniPlayer.qml`, `TrayDrawer.qml`, `StatusCluster.qml`
- **`popups/`**: Floating layer-shell popup panels (`ControlCenter.qml`, `WifiMenu.qml`, `BluetoothMenu.qml`, `AppLauncher.qml`).
- **`plugins/`**: Isolated third-party/community plugins (`omarchy-ledge/`, etc.).

---

## Guidelines for Authoring & Modifying Components

### 1. Theming & Aesthetics
Always bind colors to the `Theme` singleton rather than hardcoding hex codes:
- **Surfaces:** `Theme.barBackground`, `Theme.popupSurface`, `Theme.popupSurfaceSelected`
- **Borders:** `Theme.popupBorder`, `Theme.barBorder`
- **Text & Glyphs:** `Theme.colOnSurface` (primary text), `Theme.colOnSurfaceVariant` (muted), `Theme.primary` (accent)
- **Fonts:** `Theme.fontFamily` (Nerd Font glyphs)

### 2. Geometry & Constraints
- The top bar has an `exclusiveZone: 36` and `implicitHeight: 48` (accounting for the 12px curved corner fillets).
- Popups should use `WlrLayershell.layer: WlrLayer.Top` and `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand`.

### 3. IPC Handlers
When adding new toggleable menus or functions, register them inside `shell.qml` or within the component's `IpcHandler`:
```qml
IpcHandler {
    target: "my-target"
    function toggle(): void { ... }
}
```
Test via CLI:
```bash
quickshell ipc call <target> <function>
```

### 4. Verification & Validation
Always verify syntax before concluding changes:
```bash
# Check running quickshell instance logs
quickshell log -n 50
# Or inspect active IPC targets
quickshell ipc show
```
