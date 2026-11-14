# Dotfiles - bar + right sidebar - install notes

Vendored from <https://github.com/end-4/dots-hyprland> (branch `main`, GPL-3.0).
Only the Quickshell shell is installed; the Hyprland config, GTK/font themes and
support scripts of your own desktop are kept.

## What was installed

| Path | Purpose |
|---|---|
| `~/.config/quickshell/dotfiles/` | Upstream `ii` shell tree (bar, right sidebar, overview, session, OSD, notifications, …) |
| `~/.config/matugen/` | matugen templates + reduced config (only colors.json / color.txt / wallpaper path) |
| `~/.local/state/quickshell/.venv/` | Python venv with `pillow` + `materialyoucolor` (upstream color scripts) |
| `~/.local/state/quickshell/user/generated/colors.json` | Material You palette consumed by the shell |
| `/usr/share/fonts/TTF/GoogleSansFlex.ttf` | Google Sans Flex (upstream AUR PKGBUILD is broken: 404 source) |

System packages added: `qt6-positioning`, `kirigami`, `syntax-highlighting`,
`jq`, `bc`, `cliphist`, `hyprpicker`, `otf-space-grotesk`, `ttf-readex-pro`,
`ttf-rubik-vf`.

## Local modifications to `ii`

- `panelFamilies/DotfilesFamily.qml` (was `IllogicalImpulseFamily.qml`, renamed).
- Rebranded to **Dotfiles** (2026-11-14): the vendored shell no longer carries
  the upstream product name/branding. Renames: `~/.config/quickshell/ii` →
  `~/.config/quickshell/dotfiles`, `~/.config/illogical-impulse` →
  `~/.config/dotfiles`, `ILLOGICAL_IMPULSE_VIRTUAL_ENV` → `DOTFILES_VIRTUAL_ENV`,
  shipped icon `dotfiles` (`~/.local/share/icons/hicolor/scalable/apps/dotfiles.svg`),
  all user-visible strings (settings title, About page, welcome page,
  translations) now read "Dotfiles", and links point to
  <https://github.com/krreeshhh/DotFiles>. Upstream attribution is kept
  (`LICENSE-GPL-3.0`, Vendored-from note above). - `SidebarLeft`, `Cheatsheet`,
  `Polkit`, and `WallpaperSelector` imports and `PanelLoader`s removed (Cheatsheet,
  Polkit and WallpaperSelector disabled on request). The sources remain under
  `modules/dotfiles/{cheatsheet,polkit,wallpaperSelector}/` but are never loaded.
  Note: no polkit agent is running after this removal (your graphical sudo via
  `mechanic-askpass` / launcher auth dialog is unaffected). To re-enable a
  polkit prompt, either re-add the `Polkit` loader here or install e.g.
  `polkit-gnome` and autostart it.
- `popups/AppLauncher.qml` (your old launcher, unchanged logic) - visuals
  redesigned to match the shell: pill search bar with morphed Material Symbols tile,
  Material Symbols Rounded icons (replacing Nerd glyphs), tonal `colLayer0..2`
  surfaces with borders, rounded selection tiles (primary container), full-width
  rows with PWA/Folder/Remove chips, Material Symbol empty state, Dotfiles-style key
  hint chips. Colors come from the new derived tokens in `~/.config/quickshell/Theme.qml`
  (`colLayer0..2`, `colOnLayer0/1`, `colSubtext`, `colPrimaryContainer[Active]`,
  `colOnPrimaryContainer`, `colSecondaryContainer`, `colErrorContainer`,
  `colOutlineVariant`, `roundingNormal/Large/Full`), all computed from your
  Material You `colors.json`, so it recolors with your wallpaper automatically.
- `modules/dotfiles/bar/BarContent.qml` - left section removed: no `LeftSidebarButton`
  (distro icon) and no `ActiveWindow` label; the left-half click that toggled the
  left sidebar is disabled (scroll-to-change-brightness still works).
- `modules/dotfiles/notificationPopup/NotificationPopup.qml` - reads
  `Config.options.notifications.monitor.*` (matches the config schema).

## Two Quickshell instances

1. `~/.config/quickshell/dotfiles/` - the upstream dots-hyprland bar + right sidebar, started
   by path: `qs -p $HOME/.config/quickshell/dotfiles`.
2. `~/.config/quickshell/` (default config) - now a **launcher/auth host**: your
   previous app launcher (`popups/AppLauncher.qml`) plus `AuthDialog`/`PromptDialog`
   (used by `~/.local/bin/mechanic-askpass`). `shell.qml` was rewritten for this;
   the original is preserved in `~/.config/quickshell.bak-2026-11-14-1911/`.

The named config `-c dotfiles` cannot be used because a `shell.qml` exists at
`~/.config/quickshell/` (Quickshell disables subdirectory configs when a default
exists).

## Keybinds (in `~/.config/hypr/hyprland.lua`)

| Keys | Action |
|---|---|
| `SUPER + SPACE` | Toggle your old app launcher |
| `SUPER + C` / `SUPER + N` | Toggle right sidebar |
| `SUPER + SHIFT + N` | Close right sidebar |
| `SUPER + TAB` | Toggle Dotfiles overview/search palette |
| `SUPER + ESC` / `CTRL+ALT+Delete` | Session screen |
| `SUPER + V` | Clipse clipboard (kept) |

`SUPER + J` still toggles split; the upstream `SUPER + J` bar-toggle is not bound.

## Colors on wallpaper change

`~/.config/DotFiles/wallpaper/apply-wallpaper.sh` regenerates the `dotfiles` palette
with matugen after your own theme step. The sidebar's dark-mode toggle calls
upstream `switchwall.sh`, which uses the venv above.

## Rollback

```bash
killall quickshell
bash ~/.config/quickshell/launch.sh    # old shell (bar/, sidebar/, popups/, … still present)
```

and revert the `hyprland.lua` autostart to `hl.exec_cmd("bash /home/Krish/.config/quickshell/launch.sh")`.
Backups: `~/.config/hypr/hyprland.lua.bak-end4-*`, `~/.config/quickshell.bak-2026-11-14-1911/`.

## Notes / known differences

- Notifications are owned by Quickshell (`dotfiles`); do not run `dunst` alongside it.
- `appearance.fakeScreenRounding` defaults to `2` (rounded display corners).
  Set it to `0` in `~/.config/dotfiles/config.json` to disable.
- The old launcher's `SUPER + SPACE` search/apps/webapps views work as before
  (`remove_webapps` etc.); `~/.config/DotFiles/launcher/launcher.sh` unchanged.

## Quick sliders (sound + brightness)

The right sidebar's quick sliders (M3-styled volume + brightness control) are enabled via `sidebar.quickSliders.enable = true`
(was previously `false`). It lives above the quick toggles. `showMic` can be enabled
the same way if desired. Brightness works via `brightnessctl`.

## Overview (SUPER + TAB) removed

The Dotfiles shell's Overview/search palette is fully removed: the
`modules/dotfiles/overview` directory is deleted, its `PanelLoader` and import
are gone from `panelFamilies/DotfilesFamily.qml`, and the `SUPER + TAB`
keybind is unbound in `hyprland.lua`. The right-mouse-button-on-workspaces
overview toggle is also removed. Your old launcher on `SUPER + SPACE` is
unaffected. Note the Settings app's "Overview" section remains but adjusts
nothing since the module is not loaded.

## Calendar / To Do / Timer removed from the right sidebar

The bottom widget row in the right sidebar (Calendar, To Do, Pomodoro timer) is
removed: `BottomWidgetGroup` and the `calendar/`, `todo/`, `pomodoro/` modules
were deleted and the `BottomWidgetGroup` usage was removed from
`SidebarRightContent.qml`. The bar's clock popup still shows upcoming To-Do
items (it reads the `Todo` service directly). The settings and persistent
state keys for the bottom group are left in place but unused.

## Boosted volume (>100%)

Volume controls now go past 100% up to 154%. `services/Audio.qml` defines
`boostedMaxValue: 1.54` and uses it as the cap for button/scroll increments;
the sidebar slider (`StyledSlider` `to: 1.54`, percent tooltip disabled, shows
the raw `value * 100`); the volume OSD progress bar (`osdValues.to: 1.54`);
and the M3 Hyprland key handlers call `volume.sh`, whose `wpctl set-volume`
ceiling is now `-l 1.54` (and `set` clamps at 154 instead of 100).
Earbang protection's "Volume limit" should stay at or below 154 to match.
Note: boosting stresses speakers; keep the sidebar slider in range and don't
leave it pinned at max for long.

## Volume split (normal vs boost)

The volume control is split at 100%: the slider's track has a visible breakpoint
at 1.0 (`dividerValues`) and a `hearing` warning icon that turns red above
100%. The boosted zone (100%..`Volume limit`) is a "dangerous" region. The
actual cap for all volume changes (keys, IPC, slider, OSD) is the Dotfiles
Settings "Volume limit" (`audio.protection.maxAllowed`, 0-154, default 154 in
this machine's config). Reducing it below 100 removes the boost; increasing it
re-enables. With the default `Volume limit`, buttons and the slider can reach
154%; with 100 they are limited to 100%. Hardware keys call `volume.sh`, which
reads the same config and passes `-l <limit/100>` to `wpctl`. The earbang
protection watchdog still clamps any program that writes above the limit.

## Sidebar slider icons visible at full

The trailing icons on the sidebar's brightness and volume sliders are always
visible (they no longer fade out near the end of the range). Colour is
`colOnPrimary` on filled track, else `colOnSecondaryContainer` / `colError`
in boost.

## Interface settings stripped to Dock

The Interface page in Dotfiles Settings now shows only the Dock section
(enable, hover-to-reveal, pinned on startup, tint app icons). Removed:
Notifications, Sidebars, On-screen display, Overview, Wallpaper selector,
Fonts. Quick/General/Bar/Background/Interface pages were also reduced;
Services and Advanced pages were removed entirely.

## Settings app consolidated into a single page

The Dotfiles Settings app is now a single scrollable page with one box per
category (separator boxes): Bar & screen, Audio, Battery, Sounds, Time,
Notifications, Tray, Utility buttons, Workspaces, Dock, Distro, Dotfiles, plus a
notice box with a copy-path button. All per-page files were removed; Services and
Advanced pages were deleted entirely; the interface page keeps only Dock;
the Weather widget section was removed. The title bar has open-config,
copy-path and close buttons on the right. The app starts on the single page
(pageSource fixed) and every control was verified against the live config
schema and with live shell reaction (bar position, dock toggle, corner style,
transparent palette) applied from config.json.
