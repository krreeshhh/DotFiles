# end-4 `dots-hyprland` → Reze Quickshell: UI Analysis & Port Plan

Reference: <https://github.com/end-4/dots-hyprland> (cloned to `/tmp/opencode/dots/dots-hyprland`, commit at clone time)
License: **GPL-3.0** - fine to fork for personal use; any redistributed fork must stay GPL.

---

## 0. TL;DR

end-4 ships **two complete panel families** (`ii` = "Illogical Impulse", `waffle` = Windows-11-ish),
selected at runtime in `shell.qml` and each loaded through `panelFamilies/*Family.qml` → `PanelLoader`.

Everything you asked about lives in the **`ii` family**:

| Surface | end-4 module | ~LOC | Replaces in your setup |
|---|---|---|---|
| Top bar | `modules/ii/bar/` (24 files) | ~1 900 | `bar/*` (7 files, 1 010 LOC) |
| Right sidebar | `modules/ii/sidebarRight/` (60 files) | ~3 500 | `popups/ControlCenter.qml` + `WifiMenu` + `BluetoothMenu` |
| App launcher | `modules/ii/overview/` (5) + `services/LauncherSearch.qml` | ~1 300 | `popups/AppLauncher.qml` (1 098 LOC) |
| Session menu | `modules/ii/sessionScreen/` (2) | ~400 | `popups/SessionMenu.qml` (392 LOC) |

Recommended strategy: **surgical port (Option B)** - vendor a curated subset of end-4's
common widgets/services and rebuild the four surfaces inside your existing
`Theme.qml` + IPC contract, instead of copying the whole 8 800-line `ii` tree
(which drags in AI, booru, translation, gCloud, settings app, lock screen, etc.).

Estimated scope: **~7 500–9 000 LOC** of vendored/adapted QML across ~55 files, in 8 phases.

---

## 1. Reference architecture (what makes end-4 tick)

```
ii/shell.qml
 ├─ ReloadPopup, FirstRunExperience, ConflictKiller, Cliphist, Wallpapers…
 └─ panelFamilies/IllogicalImpulseFamily.qml
      ├─ Bar            (Variants → one PanelWindow per monitor)
      ├─ SidebarLeft    (AI/translator/anime)
      ├─ SidebarRight   (quick settings + notifications + calendar)
      ├─ Overview       (search palette + workspace overview)
      ├─ SessionScreen  (logout/shutdown)
      ├─ Lock, Dock, OSD, Polkit, MediaControls, NotificationPopup, …
```

Key patterns worth copying:

1. **`GlobalStates.qml`** - one singleton holding `sidebarRightOpen`, `overviewOpen`,
   `sessionOpen`, `mediaControlsOpen`, `screenLocked`, `superDown`, `barOpen`, …
   Every panel is `visible: GlobalStates.xxxOpen`; no cross-popup `closeImmediate()` spaghetti.
2. **`GlobalFocusGrab`** - central “click outside / Esc closes the topmost dismissable” service.
   Replaces your per-popup full-screen `MouseArea` dismissers.
3. **`Config.qml`** - persisted JSON (`~/.config/illogical-impulse/config.json`) with defaults in
   `modules/common/Config.qml`; every widget has `Config.options.*` switches (bar corner style,
   auto-hide, sidebar toggles, slider visibility…).
4. **`Appearance.qml`** - the theme engine: `m3colors` (40 M3 roles), 4-layer color system
   (`colLayer0..3` × normal/hover/active/border), `rounding`, `sizes`, `font`, `animation`.
   All UI uses `Appearance.colors.*`, never raw hex.
5. **Material Symbols Rounded** for every icon (`MaterialSymbol { text: "wifi" }`), not Nerd Font glyphs.
6. **`qs` URI imports** (`import qs.modules.common`, `import qs.services`) - `qs` is Quickshell's
   alias for the shell root. Clean module boundaries.
7. Dedicated **widget kit** (~140 files): `RippleButton`, `StyledSlider`, `StyledRectangularShadow`,
   `MaterialShape`, `Pill`, `Revealer`, `StyledToolTip`, `ClippedFilledCircularProgress`, …

---

## 2. Surface-by-surface UI analysis

### 2.1 Top bar (`modules/ii/bar/`)

**Window** - `Bar.qml`
- `Scope` → `Variants` over `Quickshell.screens` (filterable by config `bar.screenList`) →
  `LazyLoader` → `PanelWindow`.
- `exclusiveZone` = `baseBarHeight + gapsOut` normally, `0` when auto-hidden and not hovered.
- `mask: Region { item: hoverMaskRegion }` so only the bar strip receives input.
- `WlrLayershell.namespace = "quickshell:bar"`, `color: "transparent"`.
- **Auto-hide**: appears on hover or while SUPER is held (`showWhenPressingSuper.delay` ms),
  optional push-windows behaviour; slide animation via `Behavior on anchors.topMargin`.
- **Two corner styles** (`Config.options.bar.cornerStyle`):
  - `0` "Hug" - flush edge-to-edge, `RoundCorner` decorators below draw outward fillets
    (same idea as your current `leftFillet`/`rightFillet` Canvas, but reusable QML).
  - `1` "Float" - inset by `hyprlandGapsOut = 5`, `windowRounding = 18`, 1 px border,
    `StyledRectangularShadow`, floating pill look.

**Content** - `BarContent.qml`, absolutely positioned left / center / right:

| Zone | Contents |
|---|---|
| Left (half-width scroll target) | `LeftSidebarButton` (distro SVG, toggles left sidebar) + `ActiveWindow` - 2 lines: appId in `colSubtext` 12 px, window title 15 px, elided |
| Center (anchored, 3 pills) | **Pill 1** `Resources` (circular rings: RAM / swap / CPU with % text) + `Media` (circular track progress around play/pause/music icon, title • artist; LMB opens media controls, MMB play/pause, RMB next) · **Pill 2** `Workspaces` · **Pill 3** `ClockWidget` (time 17 px • bullet • long date) + `UtilButtons` + `BatteryIndicator` |
| Right (half-width scroll target) | `SysTray` (with overflow menu) + spacer + `WeatherBar` (icon + temp, hover popup) + one **indicator pill**: mute/mic-off icons (revealed only when true), XKB layout, notification unread badge, network icon, bluetooth icon |

**Interactions**
- LMB on left half → toggle left sidebar; scroll → brightness (`Brightness.*`), hover shows a `ScrollHint` moon icon tooltip.
- LMB on right half → toggle right sidebar; scroll → volume (`Audio.*`), hover shows speaker `ScrollHint`.
- `BarGroup` is the reusable “pill island”: `Rectangle` with `colLayer1` bg, radius 12, 5 px padding,
  4 px top/bottom margin (so pills are 32 px inside the 40 px bar).
- Workspaces is the showpiece: occupancy is a **stretching pill** per occupied workspace that
  over-stretches 0.5 cell toward occupied neighbours, masked by `MaskMultiEffect`, plus a
  `TrailingIndicator` for the active workspace, a hover overlay, scroll to switch, RMB → overview,
  Back button → toggle special workspace.
- Every hover target uses `StyledPopup` → a per-monitor `PanelWindow` anchored to the bar,
  x-positioned with `mapFromItem(target, (target.width - popup.width)/2, 0)`,
  margin 10, radius 12, border, shadow.
- Battery = `ClippedProgressBar` with the percentage text *inside* the fill, `bolt` when charging,
  turns `m3error` under the low threshold.

**Sizes** - bar 40 px, screen rounding 23, gaps 5, sidebar width 460, elevation margin 10,
search collapsed/expanded widths 210/360, font scale 10…23 px.

### 2.2 Right sidebar (`modules/ii/sidebarRight/`)

**Window** - `SidebarRight.qml`
- `PanelWindow` anchored top/right/bottom, `implicitWidth = 460`, `exclusiveZone: 0`,
  `WlrKeyboardFocus.OnDemand` when open, namespace `quickshell:sidebarRight`.
- Content inset by `hyprlandGapsOut` (and an extra `elevationMargin` on the left) so it floats
  with a gap from the screen edges and the bar.
- Registered as `GlobalFocusGrab.addDismissable()`; Esc and click-outside close it.

**Body** - `SidebarRightContent.qml` (ColumnLayout, padding 10, spacing 10)

1. **`SystemButtonRow`**
   - Uptime pill: distro icon + `Up 3d 4h`, `colLayer1`, fully rounded.
   - 4 circular buttons in a `ButtonGroup`: *edit quick toggles*, *reload Hyprland + Quickshell*,
     *open settings app*, *power* (→ session screen).
2. **`QuickSliders`** - one `colLayer1` rounded card:
   - Brightness + gamma **combined** on one slider: 0–0.3 maps to gamma, 0.3–1.0 to brightness;
     two icons (sun / twilight), a `dividerValues` tick at the 0.3 boundary, tooltip shows
     `45 %` or `Gamma 82 %`.
   - Volume slider (speaker icon rides the handle).
   - Optional mic slider.
3. **Quick toggles** - `AbstractQuickPanel` with two implementations:
   - **`AndroidQuickPanel`** (default): 5-column grid, each tile `size` 1 or 2 columns,
     height 56, radius `large` when on / half-height when off; tile shows icon + name + status text;
     tapping the icon area runs the *primary* action while tapping the body opens the *detail dialog*
     (Wi-Fi list, BT list, volume mixer…).
     - **Edit mode**: LMB enable/disable, RMB toggle 1×/2× size, scroll reorder, unused toggles
       shown below a divider. Persisted to config.
   - **`ClassicQuickPanel`**: small round icon buttons + labels.
   - Toggle model set: network, bluetooth, idle inhibitor (caffeine), EasyEffects, night light,
     dark mode, Cloudflare WARP, game mode, screen snip, colour picker, OSK, mic, audio,
     notifications, power profile, music recognition, anti-flashbang.
4. **`CenterWidgetGroup`** - notification centre filling leftover height: grouped list,
   app icon, summary/body, timestamp, actions, dismiss; “silent” state; scroll.
5. **`BottomWidgetGroup`** - 350 px collapsible card with a **vertical navigation rail**
   (Calendar, To Do, Timer) and animated content swap (fade + 10 px slide, direction-aware).
   Collapsed state shows `Fri, 14/11 • 3 tasks` and an up-chevron.
   - Calendar: month grid, day buttons, header paging.
   - To Do: task rows with checkboxes.
   - Timer: pomodoro + stopwatch.
6. **In-sidebar dialogs** (overlay inside the same window, `ToggleDialog` loader):
   Wi-Fi networks, Bluetooth devices, audio output, audio input, night light.
   Your existing `WifiMenu.qml` / `BluetoothMenu.qml` logic can be moved here almost verbatim.

**IPC/shortcuts** - `sidebarRight toggle|open|close`, `GlobalShortcut sidebarRight{Toggle,Open,Close}`.

### 2.3 App launcher - actually the **Overview command palette** (`modules/ii/overview/`)

Important: end-4's `ii` family has **no icon-grid launcher**. SUPER opens a full-screen
transparent window containing a **shrinking/expanding search card at the top-centre**, with an
optional workspace overview underneath when the query is empty. (`waffle` has an icon-grid Start
menu, but it is a separate panel family - don't mix them.)

- `PanelWindow` full-screen, `WlrLayer.Top`, keyboard focus on demand, `mask` = column,
  namespace `quickshell:overview`.
- **Card** (`SearchWidget`): `colBackgroundSurfaceContainer`, radius = search-bar height/2 + padding,
  `clip: true`, animated implicit height; `StyledRectangularShadow`; opacity mask so the expanding
  list is clipped to the rounded top.
- **Search row** (`SearchBar`):
  - Morphing `MaterialShape` icon that changes **shape + symbol** per query prefix:
    `/` actions → pill, `>` apps → clover, `;` clipboard → gem, `:` emoji → sunny,
    `=` math → puffy diamond, `$` shell → pixel circle, `?` web → soft burst, default → 7-sided cookie.
  - `ToolbarTextField` 40 px, width 210 → 360 animated when the palette opens.
  - Two circular toolbar buttons: Google Lens region search, music recognition
    (rotating `SoftBurst` background while listening).
- **Results** (only when query ≠ ""): 1 px separator + `ListView` (max height 600, ~15 results,
  200 ms debounce). Each row: leading app icon / Material symbol / emoji / text thumbnail,
  fuzzy-highlighted name (per-character underline in `colPrimary`), type label (“App”, “Action”,
  “Clipboard”, “Emoji”, “Shell”, “Web”) and action verb (Open / Run / Copy / Go).
  Up/Down navigate, Enter runs, Tab autocompletes the top result, Shift+Delete removes a
  clipboard/history entry.
- **Empty query**: `OverviewWidget` - animated grid of workspaces with live window thumbnails,
  drag windows between workspaces, workspace numbers.
- **Search engine** (`services/LauncherSearch.qml`) unifies: desktop apps, built-in actions
  (`dark`, `light`, accent colour…), user scripts from `~/.config/illogical-impulse/actions/`,
  clipboard history, emoji, calculator (QML math), shell commands, web search fallback,
  plus `LauncherApps` scanning `.desktop` files. `LauncherSearchResult` model carries
  `name/iconName/iconType/type/verb/execute/actions`.
- Global shortcuts for palette, clipboard-only (`;`), emoji-only (`:`), and a
  press/release-safe SUPER-tap toggle.

**Port note for Krish**: keep your web-app manager (`webapp_manager.py`, `webapps` /
`remove_webapps` views) as a **prefixed view** (e.g. `@` or a toolbar button) inside this palette,
rather than as the whole launcher. That preserves your PWA workflow while adopting the
command-palette UX.

### 2.4 Session / power menu (`modules/ii/sessionScreen/`)

- Full-screen `PanelWindow` on the focused monitor, `WlrLayer.Overlay`,
  `keyboardFocus: Exclusive`, background = `m3background` with only 5 % (dark) / 12 % (light)
  transparency, so the desktop is still visible through a tinted scrim.
- Centered `ColumnLayout`: title “Session” (title font), instruction line
  “Arrow keys to navigate, Enter to select / Esc or click anywhere to cancel”.
- **4 × 2 grid of 120 px buttons** (`SessionActionButton`):
  Lock · Sleep · Logout · Task Manager · Hibernate · Shutdown · Reboot · Reboot to firmware.
  - Idle: rounded square (`verylarge = 30 px`), `colSecondaryContainer`.
  - Hover/focus: morphs to a **circle** (`radius = size/2`), background `colPrimary`,
    icon `m3onPrimary`; ripple.
  - Icon-only (Material symbol, 45 px); the label appears in a floating tooltip chip below the grid.
- Arrow keys wired with `KeyNavigation`; a `DescriptionLabel` chip under the grid shows the
  focused action’s name and animates its width.
- Warning chips below: “package manager is running”, “download might be in progress”
  (`SessionWarnings` service).
- Esc / click-anywhere closes; `GlobalStates.sessionOpen` drives it; IPC `session toggle|open|close`.

---

## 3. Gap analysis: your build vs end-4

| Capability | Now | Needed for end-4 look |
|---|---|---|
| Icons | Nerd Font glyphs (`󰤨`) | `ttf-material-symbols-variable` (in `extra`) + `MaterialSymbol` component |
| Theme tokens | 13 flat colors in `Theme.qml` | `m3colors` roles + `colLayer0..3` (+hover/active/border) + `rounding`/`sizes`/`animation` |
| Config | hardcoded in QML | persisted `Config` singleton (JSON) for bar/sidebar/launcher options |
| State | per-popup `visible/shown` + manual `closeImmediate()` fan-out in `shell.qml` | `GlobalStates` + `GlobalFocusGrab` |
| Services | `Process` calls inside widgets (`wpctl`, `brightnessctl`, `bluetoothctl`, `wifi.py`) | singletons: `Audio`, `Brightness`, `Network`, `BluetoothStatus`, `Battery`, `ResourceUsage`, `Notifications`, `MprisController`, `DateTime` |
| Quick settings | 380 px dropdown, 2×2 tiles, 2 sliders | full-height 460 px sidebar: uptime, 3 sliders, toggle grid, notifications, calendar/todo/timer |
| Launcher | 540×520 centred card, app list + PWA views | top-centre expanding command palette + optional workspace overview |
| Session menu | 560×388 centred card with 5 rows | full-screen scrim + 4×2 circular buttons, 8 actions, keyboard-first |
| Notifications | none | notification centre + unread badge + popups |
| Bar layout | fixed left/centre/right, glass + Canvas fillets | 3 centred pill islands, floating/hug corner styles, auto-hide, scroll zones, hover popups |
| Workspaces | animated dots | stretching-pill occupancy + active trailing indicator |
| Widget kit | ad-hoc `Rectangle`s | `RippleButton`, `StyledSlider`, `Pill`, `Revealer`, `StyledToolTip`, … |
| Dead code | `qs/Commons/Commons/`, `qs/Ui/Ui/` recursive copies | clean before porting |

Non-blocking deps to note: `hyprsunset` (night light/gamma), `hyprpicker` (colour picker),
`wf-recorder` (screen record), `matugen`/`materialyoucolor` (optional full M3 scheme).
Not installed today; all are optional toggles.

---

## 4. Target architecture for Reze

```
~/.config/quickshell/
├── shell.qml                  # orchestrator only: Variants, GlobalStates wiring, IPC
├── Theme.qml                  # keep, extend (see §5)
├── lib/                       # ported end-4 widget kit (curated)
│   ├── MaterialSymbol.qml
│   ├── RippleButton.qml
│   ├── StyledRectangularShadow.qml
│   ├── StyledSlider.qml
│   ├── MaterialShape.qml + MaterialShapeWrappedMaterialSymbol.qml
│   ├── RoundCorner.qml
│   ├── Pill.qml
│   ├── Revealer.qml
│   ├── ClippedFilledCircularProgress.qml / ClippedProgressBar.qml
│   ├── MaskMultiEffect.qml
│   ├── ToolbarTextField.qml / IconToolbarButton.qml
│   ├── NavigationRailButton.qml / ButtonGroup.qml / GroupButton.qml
│   └── StyledToolTip.qml
├── services/
│   ├── GlobalStates.qml / GlobalFocusGrab.qml / Config.qml / Persistent.qml
│   ├── Audio.qml / Brightness.qml / Network.qml / BluetoothStatus.qml
│   ├── Battery.qml / ResourceUsage.qml / DateTime.qml
│   ├── Notifications.qml / MprisController.qml
│   ├── LauncherSearch.qml / LauncherApps.qml / Session.qml / Wallpapers.qml
├── bar/                       # rewrite of the current folder
│   ├── Bar.qml  BarContent.qml  BarGroup.qml  StyledPopup.qml
│   ├── Workspaces.qml (stretching pill)
│   ├── ActiveWindow.qml  Resources.qml  Media.qml  ClockWidget.qml
│   ├── UtilButtons.qml  BatteryIndicator.qml  SysTray.qml
│   └── StatusCluster.qml (indicator pill)  WeatherBar.qml (optional)
├── sidebar/
│   ├── SidebarRight.qml  SidebarRightContent.qml  SystemButtonRow.qml
│   ├── QuickSliders.qml  QuickPanel.qml  QuickToggleButton.qml
│   ├── toggles/{Network,Bluetooth,NightLight,DarkMode,IdleInhibitor,Mic,Audio,Notifications}.qml
│   ├── NotificationList.qml
│   ├── BottomWidgetGroup.qml  calendar/  todo/  timer/
│   └── dialogs/{WifiDialog,BluetoothDialog,VolumeDialog}.qml   # ← reuse existing menus
├── launcher/
│   ├── Launcher.qml  SearchWidget.qml  SearchBar.qml  SearchItem.qml
│   ├── WorkspaceOverview.qml (optional, phase 7)
│   └── webapps/ (your PWA manager integration)
├── session/
│   ├── SessionScreen.qml  SessionActionButton.qml
└── popups/                    # keep: AuthDialog, PromptDialog, Osd
```

`qs` URI imports are possible (`QML_IMPORT_PATH` is already `~/.config/quickshell`), but your
existing code uses relative imports consistently. Recommend **relative imports inside each
folder** (`import "../lib"`, `import "../services"`) for lower-risk incremental work, and only
introduce a `qmldir` module if/when the tree stabilises.

---

## 5. Design tokens to add to `Theme.qml`

Keep `generate-theme.py` and `colors.json` untouched initially; **derive** the extra roles in QML.

```qml
// Derived M3 roles (from your 13 tokens)
property color colOnPrimaryContainer: Qt.lighter(primaryContainer, 1.8)
property color colSecondaryContainer:  Qt.rgba(secondary.r, secondary.g, secondary.b, 0.22)
property color colOnSecondaryContainer: secondary
property color colTertiary: secondary
property color colError: colorError
property color colOnError: "#2a0a0a"
property color colOutlineVariant: outline

// 4-layer system (compute with a mix helper, as end-4 does)
colLayer0       = background @ 45% (== barBackground)
colLayer1       = surface @ 40–55%  (pills, cards inside popups)
colLayer2       = surfaceVariant @ 35% (toggle tiles)
colLayer3       = surfaceVariant @ 55%
colOnLayer0..3  = colOnSurface / colOnSurfaceVariant
colLayer0Border = outline @ 30% (== popupBorder)

// Metrics
barHeight: 40, barGroupRadius: 12, screenRounding: 23, windowRounding: 18
sidebarWidth: 460, elevationMargin: 10, hyprlandGapsOut: 5
sessionButtonSize: 120, launcherSearchWidth: 210/360
animation: elementMove 300ms cubic-bezier(.2,0,0,1), fast 150ms
```

Optional later: extend `generate-theme.py` with `materialyoucolor` to emit the full M3 scheme
(surfaceContainerLow…Highest, secondaryContainer, tertiary, errorContainer, inverse*), which
removes the need for derived approximations and makes light mode viable.

**Rule:** no hex literals in ported UI; replace end-4's `Appearance.colors.*` with `Theme.*`
(mechanical sed, then manual review). Keep the glass look by keeping layer transparencies.

---

## 6. Phased implementation plan

### Phase 0 - Prep & safety (30 min)
- Back up: `cp -a ~/.config/quickshell ~/.config/quickshell.bak-$(date +%F)`; also snapshot
  `hyprland.lua`, `hyprland.conf`, `~/.config/DotFiles/theme`.
- `sudo -A pacman -S ttf-material-symbols-variable` (asks password via your Quickshell dialog).
  Verify `fc-list | grep "Material Symbols Rounded"`.
- Delete dead scaffolding `qs/Commons/Commons/`, `qs/Ui/Ui/` (recursive duplicates) after confirming
  nothing imports them.
- Acceptance: shell still starts (`quickshell -p ~/.config/quickshell`), font visible.

### Phase 1 - Foundation: state, config, theme, services (1–2 sessions)
- Add `services/GlobalStates.qml` (flags listed in §1) and `services/GlobalFocusGrab.qml`.
- Add minimal `services/Config.qml` (JSON at `~/.config/quickshell/config.json`) with:
  `bar.{cornerStyle, autoHide, showBackground, verbose, modules}`, `sidebar.{width, quickToggles.style}`,
  `search.prefix.*`. Not the whole end-4 config tree.
- Extend `Theme.qml` per §5; add `Theme.anim` and `Theme.metrics` groups.
- Port services in this order: `DateTime` (replace `bar/Clock` timer), `Battery`, `Audio`,
  `Brightness`, `Network`, `BluetoothStatus`, `ResourceUsage`, `MprisController`, `Notifications`.
  Use `Quickshell.Services.*` where possible (UPower, Pipewire, Mpris, Bluetooth, Notifications,
  Network) instead of shelling out - this alone removes most of your `Process` blocks.
- Rewire `shell.qml` IPC to call `GlobalStates`; keep the **existing IPC method names**
  (`toggleControlCenter`, `toggleAppLauncher`, `toggleSessionMenu`, `searchAppLauncher`, …) as thin
  aliases so `hyprland.lua` keeps working during the migration.
- Acceptance: no visual regression; all IPC still works; `journalctl` clean.

### Phase 2 - Widget kit (1–2 sessions)
Port/adapt in this order (each is self-contained):
`MaterialSymbol`, `StyledRectangularShadow` (needs `MultiEffect`), `RippleButton`,
`StyledSlider` (M3 track/stop indicators/divider marks), `Revealer`, `Pill`, `RoundCorner`,
`ClippedProgressBar`, `ClippedFilledCircularProgress`, `MaskMultiEffect`,
`MaterialShape` + wrapped symbol, `ToolbarTextField`, `IconToolbarButton`,
`ButtonGroup`/`GroupButton`, `NavigationRailButton`, `StyledToolTip`.
Rewrite end-4's `Appearance.*` references to `Theme.*`.
- Acceptance: a throwaway `widget-gallery.qml` (`quickshell -p`) renders every widget with live
  theme reload. Delete afterwards.

### Phase 3 - Top bar (2–3 sessions)
1. `BarGroup` pill + `BarContent` three-zone layout; replace fixed left/right rows.
2. Status cluster pill (volume/mic mute reveals, xkb, unread, network, BT) + `SysTray`.
3. `ActiveWindow` two-line label; `ClockWidget`; `UtilButtons` (start with screenshot + colour
   picker + caffeine; add record/OSK when deps install).
4. `Resources` rings + `Media` ring (port `MprisController`).
5. Workspaces stretching-pill (port `WorkspaceModel` + `TrailingIndicator` + `MaskMultiEffect`).
6. `StyledPopup` infrastructure + migrate `MiniPlayer` popup, battery popup, calendar popup.
7. Corner style switch: `hug` (reuse your Canvas fillets, optionally swap for `RoundCorner`) and
   `float` (gaps + shadow). Bar height 40, exclusiveZone 40.
8. Auto-hide + SUPER-hold reveal (needs `GlobalStates.superDown` fed by a Hyprland submap bind).
- Keep `LedgeWidget` in the right zone (your feature, not in end-4).
- Acceptance: turning config `bar.cornerStyle` switches layouts live; scroll zones work;
  no flicker on monitor hotplug.

### Phase 4 - Right sidebar (3–4 sessions, biggest chunk)
1. `SidebarRight.qml` window + `GlobalStates.sidebarRightOpen` + focus grab + Esc.
2. Shell: `SystemButtonRow` → three right-zone buttons + uptime.
3. `QuickSliders` (volume + brightness; add gamma only if `hyprsunset` installed).
4. `QuickPanel` (Android style) with 8 toggles: network, bluetooth, idle-inhibitor→`caffeine.sh`,
   dark mode→`apply-theme.sh --mode`, night light (optional), mic, audio, notifications.
   Include edit mode + persisted layout.
5. `NotificationList` + `Notifications` service + unread badge wiring to the bar.
6. `BottomWidgetGroup`: calendar first (port `CalendarWidget`), then To Do, then Timer.
7. Move `WifiMenu`/`BluetoothMenu` bodies into `dialogs/WifiDialog`/`BluetoothDialog`
   (reuse `scripts/wifi.py` and `bluetoothctl` logic as-is), opened from toggles.
8. Remove `ControlCenter.qml`; keep `toggleControlCenter` IPC aliased to sidebar toggle.
- Acceptance: SUPER+C opens the sidebar; toggles reflect real state within 1 s; notifications
  arrive/dismiss; calendar month navigation; Esc/click-outside close; theme reload propagates.

### Phase 5 - Launcher / command palette (2–3 sessions)
1. `Launcher.qml` full-screen `PanelWindow` + top-centre expanding card + mask + shadow.
2. `SearchBar` with prefix-driven shape/symbol morph; keep Nerd/`Material` hybrid if needed.
3. `LauncherSearch` service: desktop apps first, then actions, clipboard (`clipse`), math,
   shell (`$`), web (`?`); fuzzy scoring (port `fuzzysort.js` + `Fuzzy.qml` or a simpler
   `Levenshtein` subset); 200 ms debounce; highlighted matches.
4. Results `SearchItem` row: icon, name, type, verb, keyboard nav, Enter/Tab/Shift+Delete.
5. Re-integrate PWA manager as a **view** (toolbar button / `@` prefix): list, create, remove -
   keep `webapp_manager.py` and its JSON contract.
6. Keep IPC names: `toggleAppLauncher`, `openAppLauncher(view)`, `searchAppLauncher(q)`,
   `selectAppLauncherIndex(i)`, `removeWebApps`.
7. Optional: workspace overview under an empty query (port `OverviewWidget`) - defer to Phase 7
   because it needs window thumbnails (`ToplevelManager`) and drag/drop.
- Acceptance: SUPER+SPACE opens in <100 ms; typing an app name launches on Enter; `;` shows
  clipboard; PWA create/remove still works; Esc/click-outside close.

### Phase 6 - Session screen (1 session)
1. `SessionScreen.qml` full-screen scrim on focused monitor + `SessionActionButton`.
2. Eight actions wired to **your existing scripts** (`lock.sh`, `logout.sh`, `suspend.sh`,
   `systemctl reboot/poweroff`, `hyprshutdown` if present) instead of end-4's `Session` helper.
3. Keyboard: 4×2 `KeyNavigation`, Enter, Esc, click-outside; subtitle chip; warning chips
   (pacman lock `/var/lib/pacman/db.lck`, running downloads) optional.
4. Delete `SessionMenu.qml`; keep IPC names.
- Acceptance: SUPER+ESC opens; arrows + Enter work; each action executes; no stuck keyboard focus.

### Phase 7 - Polish & integration (1–2 sessions)
- Restyle `Osd.qml` to end-4's indicator card (icon + thin bar + value), keep your IPC.
- Notification popups (top-right, grouped) if desired.
- Hyprland: layer rules for new namespaces (`quickshell:bar`, `quickshell:sidebarRight`,
  `quickshell:overview`, `quickshell:session`) with blur/ignorealpha as end-4 does.
- Bindings in `hyprland.lua`: `sidebarRightToggle` (e.g. SUPER+N / SUPER+C), keep SUPER+SPACE,
  SUPER+ESC; ensure `quickshell ipc` target names match.
- Theme: extend `generate-theme.py` (optional) to emit full M3 roles; verify `apply-theme.sh`
  live reload paints every new surface without restart.
- Cleanup: remove replaced files, dead `qs/` scaffolding, unused imports; update `launch.sh` env
  (`QS_NO_RELOAD_POPUP=1`, `QT_QUICK_CONTROLS_STYLE=Basic`).
- Acceptance: full checklist in §9.

---

## 7. Dependencies

| Need | Package | Status |
|---|---|---|
| Material icons | `ttf-material-symbols-variable` (extra) | **must install** |
| Shadows/MultiEffect | `qt6-declarative` (QtQuick.Effects) | installed |
| Old GraphicalEffects (optional) | `qt6-5compat` | installed |
| Night light / gamma | `hyprsunset` | optional |
| Colour picker | `hyprpicker` | optional |
| Screen record | `wf-recorder` | optional |
| Screenshots | `grim` + `slurp` | installed |
| Brightness | `brightnessctl` | installed |
| Media | `playerctl`, Quickshell Mpris | installed |
| Notifications | Quickshell `NotificationServer` + `dunst`? | dunst config exists; **avoid running both** - decide one owner |

Version check: Quickshell 0.3.2 + Qt 6.12 + Hyprland 0.57.2 support every API used
(`PanelWindow`, `WlrLayershell`, `mask`/`Region`, `IpcHandler`, `GlobalShortcut`,
`Quickshell.Services.{UPower,Pipewire,Mpris,Bluetooth,Notifications}`, `Qt.labs.synchronizer`).

---

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| GPL-3.0 code | Personal config is fine; keep attribution header in vendored files; don't publish as MIT |
| End-4 `Appearance`/`Config` references everywhere | Do the token rewrite during Phase 2 before touching UI files; script the rename |
| `MaterialSymbol` names differ from your Nerd glyphs | Maintain a tiny `icons.json` map for the ~40 icons actually used |
| Two notification daemons (dunst + Quickshell) | Pick Quickshell `NotificationServer`, disable dunst service, or skip notification centre initially |
| Bar auto-hide vs Hyprland gaps/exclusive zone | Test `exclusiveZone: 0` + `mask`; keep a config escape hatch |
| Losing current IPC contract | Keep old `IpcHandler` names as aliases for one release; grep `hyprland.lua` + scripts |
| Multi-monitor popups | `StyledPopup` must be per-monitor; validate on a second virtual output or `hyprctl output create headless` |
| Theme reload flicker/leaks | Extend `Theme.qml` only with derived colors; keep the 1.5 s poll during migration, switch to IPC reload later |
| Scope creep (AI sidebar, booru, lock, dock) | Explicitly out of scope; do not port `sidebarLeft`, `Lock`, `Dock`, `settings.qml` |

---

## 9. Verification checklist (post-port)

- [ ] `quickshell -p ~/.config/quickshell` starts with no QML warnings in journal.
- [ ] Bar: 3 pill groups, correct height, fillets/float switch, hover popups aligned to targets.
- [ ] Scroll on left half changes brightness; right half changes volume; OSD appears.
- [ ] Workspaces: pill stretches across occupied neighbours; click/scroll/RMB behave.
- [ ] Sidebar: SUPER+C toggle, Esc/click-outside close, sliders move real hardware,
      toggles persist, notifications show, calendar/todo/timer switch tabs.
- [ ] Launcher: SUPER+SPACE, fuzzy app search, `;` clipboard, `=` math, `?` web, PWA view.
- [ ] Session: SUPER+ESC, arrow+Enter, all 8 actions, no focus leak.
- [ ] Theme: `apply-theme.sh` on a new wallpaper updates every surface live.
- [ ] `hyprctl reload` does not break layer namespaces; monitors survive suspend/resume.
- [ ] Idle/lock still work (`hypridle` unaffected).

---

## 10. Open decisions

1. **Corner style default**: end-4 floating islands (`cornerStyle 1`) vs your current flush
   glass + Canvas fillets (`cornerStyle 0`). Recommendation: implement both, default to `0`
   to preserve your identity, `1` as an option.
2. **Notification owner**: Quickshell notification centre (drop dunst) or keep dunst and
   show unread only? Recommendation: Quickshell centre, disable dunst to avoid double popups.
3. **Launcher shape**: keep your 540×520 card and restyle it, or adopt the top-centre
   expanding palette? Recommendation: adopt end-4's palette (it is the signature interaction)
   and fold PWA management in as a view.
4. **Sidebar bottom widget scope**: all three tabs (calendar/todo/timer) or calendar only first?
   Recommendation: calendar + todo, defer timer.
5. **Scope**: do we also want `sidebarLeft` (AI chat), dock, lock screen, overview window
   thumbnails? Recommendation: no for v1; revisit after Phase 6.

---

## Appendix A - files worth copying verbatim (then retheme)

```
modules/common/widgets/MaterialSymbol.qml
modules/common/widgets/RippleButton.qml
modules/common/widgets/StyledRectangularShadow.qml
modules/common/widgets/StyledSlider.qml
modules/common/widgets/Revealer.qml
modules/common/widgets/Pill.qml
modules/common/widgets/RoundCorner.qml
modules/common/widgets/ClippedProgressBar.qml
modules/common/widgets/ClippedFilledCircularProgress.qml
modules/common/widgets/MaskMultiEffect.qml
modules/common/widgets/MaterialShape.qml
modules/common/widgets/MaterialShapeWrappedMaterialSymbol.qml
modules/common/widgets/ToolbarTextField.qml
modules/common/widgets/IconToolbarButton.qml
modules/common/widgets/ButtonGroup.qml
modules/common/widgets/GroupButton.qml
modules/common/widgets/NavigationRailButton.qml
modules/common/widgets/StyledToolTip.qml
modules/common/widgets/StyledText.qml
modules/common/models/WorkspaceModel.qml
modules/ii/bar/{BarGroup,Workspaces,ActiveWindow,Resources,Media,ClockWidget,UtilButtons,BatteryIndicator,SysTray,StyledPopup}.qml
modules/ii/sidebarRight/{SidebarRightContent,QuickSliders,BottomWidgetGroup}.qml
modules/ii/sidebarRight/quickToggles/androidStyle/*
modules/ii/sidebarRight/calendar/*
modules/ii/sessionScreen/*
modules/ii/overview/{SearchBar,SearchWidget,SearchItem}.qml
services/{ResourceUsage,MprisController,Notifications,LauncherSearch}.qml
modules/common/functions/{fuzzysort.js,ColorUtils.qml,StringUtils.qml}
```

## Appendix B - explicitly skip

`modules/ii/sidebarLeft/*` (AI, translator, booru), `modules/settings/*`, `settings.qml`,
`welcome.qml` (first-run wizard), `modules/ii/lock/*`, `modules/ii/dock/*`,
`modules/waffle/*`, `services/{Ai,GoogleCloud,Booru,SongRec,Translation,LatexRenderer}.qml`,
`modules/ii/regionSelector/*`, `modules/ii/polkit/*`, `modules/ii/component/*`.
