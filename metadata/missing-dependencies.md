# Missing Dependencies & Manual Upstream Audit

The following items are preserved in binary or asset form within this export because their exact package manager origin could not be traced to a single official Arch package:

1. **`awww` and `awww-daemon` (`~/.local/bin/awww`):**
   - **Status:** Exported in `bin/awww` and `bin/awww-daemon`.
   - **Notes:** High-performance animated wallpaper switcher. If compiling from source or substituting, standard `swww` or `swaybg` can be used. The scripts automatically fall back if `awww` is missing.

2. **SDDM Theme `R1999_1` (`/usr/share/sddm/themes/R1999_1`):**
   - **Status:** Exported completely in `assets/themes/sddm/R1999_1/`.
   - **Notes:** Unowned by pacman (manually installed). Preserved in the export to be copied directly into `/usr/share/sddm/themes/`.

3. **Wallpaper Images (`~/.wallpaper/`):**
   - **Status:** Manifest generated in `assets/wallpapers/WALLPAPER_MANIFEST.txt`.
   - **Notes:** Contains 25 personal wallpaper image files (120MB total). Recreating on a new machine requires placing favorite wallpapers into `~/.wallpaper/` (or restoring personal wallpaper directory).
