# Hardware-Specific Configuration Reference

The following settings are tied to this specific machine (ASUS Laptop, AMD Ryzen 5 7535HS + NVIDIA GeForce RTX 2050 Mobile):

## 1. NVIDIA Graphics & Power Management
* **GPU Model:** NVIDIA GeForce RTX 2050 Mobile (GA107M, 4GB VRAM)
* **Kernel Parameter:** `nvidia.NVreg_PreserveVideoMemoryAllocations=1` in GRUB command line.
* **Kernel Driver:** `nvidia-open-dkms` (v615.71.09) with `modeset=1` and `fbdev=1`.
* **System Services:** `nvidia-suspend.service`, `nvidia-resume.service`, `nvidia-hibernate.service` (Required to prevent blank screen / corrupted VRAM on resume).
* **Hardware Video Acceleration:** `/etc/environment` specifies `LIBVA_DRIVER_NAME=nvidia` with `libva-nvidia-driver`.

## 2. Display Panel (`eDP-1`)
* **Display Output ID:** `eDP-1` (Internal Laptop Display, Chimei Innolux Corporation 0x1521).
* **Native Resolution & Refresh Rate:** `1920x1080 @ 144.003Hz`.
* **Hyprland Rule:**
  ```lua
  hl.monitor({
      output   = "",
      mode     = "preferred",
      position = "auto",
      scale    = "1",
  })
  ```
  *(Generic fallback is enabled in config, but refresh rate optimizations in `config.env` specify `144` fps).*

## 3. Input Devices & Laptop Features
* **Touchpad:** `natural_scroll = false` in `hyprland.lua`.
* **Brightness Control:** `brightnessctl -e4 -n2 set 5%+` and `5%-` mapped to ASUS WMI hotkeys (`XF86MonBrightnessUp` / `XF86MonBrightnessDown`).
* **Volume Control:** `wpctl set-volume` mapped to `XF86AudioRaiseVolume` / `XF86AudioLowerVolume`.
