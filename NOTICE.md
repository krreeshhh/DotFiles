# Upstream attribution

This tree (`config/quickshell/dotfiles/`) is a vendored and modified copy of
[`end-4/dots-hyprland`](https://github.com/end-4/dots-hyprland) (branch `main`),
released under the **GPL-3.0** license. The full license text is kept in
`LICENSE-GPL-3.0` next to this file.

Original copyright: Copyright (C) end-4 and contributors.

Local modifications relative to upstream (see `~/.config/dotfiles/DOTFILES-INSTALL.md`):

- `panelFamilies/DotfilesFamily.qml` - `SidebarLeft`, `Cheatsheet`, `Polkit`,
  `WallpaperSelector` imports/loaders removed.
- `modules/dotfiles/bar/BarContent.qml` - `LeftSidebarButton` and `ActiveWindow`
  removed from the left side of the bar.
- `modules/dotfiles/notificationPopup/NotificationPopup.qml` - reads
  `Config.options.notifications.monitor.*` (config-schema fix).
- Rebranded to **Dotfiles** (paths, `panelFamilies`, module dir, window titles,
  translations, icon). All upstream attribution is retained.

The `modules/dotfiles/common/widgets/shapes/` directory vendors the
[rounded-polygon-qmljs](https://github.com/end-4/rounded-polygon-qmljs) helper
(loads `material-shapes.js` shapes). Its `LICENSE` and `README.md` are kept.
