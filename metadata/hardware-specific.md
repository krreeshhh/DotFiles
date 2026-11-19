# Universal Hardware Detection & Driver Matrix Reference

This repository features an automated Universal Hardware Detection & Driver Engine (`install.sh`) that dynamically interrogates the system architecture, CPU microcode, GPU vendor/generation, chassis type, kernel flavor, and hardware quirks to deploy the exact matching driver and configuration stack on any Arch Linux machine.

---

## 1. Hardware Detection Engine Architecture

When `./install.sh` executes (or when run with `--scan`), the engine interrogates the live system across the following hardware tiers:

### A. CPU Architecture & Microcode
* **AMD Processors:** Probes `AuthenticAMD` via `/proc/cpuinfo` -> Installs `amd-ucode`.
* **Intel Processors:** Probes `GenuineIntel` via `/proc/cpuinfo` -> Installs `intel-ucode`.

### B. Linux Kernel & Development Headers
* Detects running kernel via `uname -r` and automatically selects matching headers:
  * `linux` -> `linux-headers`
  * `linux-lts` -> `linux-lts-headers`
  * `linux-zen` -> `linux-zen-headers`
  * `linux-hardened` -> `linux-hardened-headers`

### C. Graphics Processing Units (GPU Matrix)
The engine scans PCI devices via `lspci` for all display controllers (VGA/3D):
* **NVIDIA Turing+ (RTX 20xx, 30xx, 40xx, GTX 16xx):**
  * Drivers: `nvidia-open-dkms`, `nvidia-utils`, `lib32-nvidia-utils`, `libva-nvidia-driver`, `egl-wayland`
  * Services: `nvidia-suspend`, `nvidia-resume`, `nvidia-hibernate`
  * Early KMS: Adds `nvidia nvidia_modeset nvidia_uvm nvidia_drm` to mkinitcpio modules
  * Modprobe: `options nvidia-drm modeset=1 fbdev=1`, `options nvidia NVreg_PreserveVideoMemoryAllocations=1`
* **NVIDIA Pre-Turing (Pascal, Maxwell, Kepler):**
  * Drivers: `nvidia-dkms` (proprietary branch) + matching 32-bit and VA-API libraries
* **AMD Radeon (GCN, RDNA, RDNA 2, RDNA 3):**
  * Drivers: `mesa`, `lib32-mesa`, `vulkan-radeon`, `lib32-vulkan-radeon`, `libva-mesa-driver`, `mesa-vdpau`
  * Early KMS: Adds `amdgpu` to mkinitcpio
* **Intel Graphics (Iris Xe, Arc, HD Graphics):**
  * Drivers: `mesa`, `lib32-mesa`, `vulkan-intel`, `lib32-vulkan-intel`, `intel-media-driver` (VA-API), `libva-intel-driver`
  * Early KMS: Adds `i915` or `xe` to mkinitcpio
* **Virtual Machines (QEMU, KVM, VirtualBox, VMware):**
  * Probed via `systemd-detect-virt`
  * VirtualBox: `virtualbox-guest-utils`
  * QEMU/KVM: `qemu-guest-agent`, `spice-vdagent`
  * VMware: `open-vm-tools`, `xf86-video-vmware`

### D. Audio DSP & Sound Open Firmware
* Scans PCI devices for Intel DSP / AMD ACP audio controllers:
  * Automatically installs `sof-firmware` and `alsa-ucm-conf` for modern digital microphones and multi-speaker DSP arrays.

### E. Vendor-Specific Hardware Quirks
* **ASUS TUF / ROG Laptops:**
  * Detects ASUS DMI product / chassis strings
  * Deploys `asusctl`, `supergfxctl`, and white keyboard backlight persistence service (`asus-kbd-white.service`).
* **Realtek RTL8852BE / RTL8852CE Wi-Fi:**
  * Automatically applies power-save and ASPM disable options in `/etc/modprobe.d/rtw89.conf` to prevent intermittent Wi-Fi drops.
* **Realtek RTL8852BU USB Bluetooth:**
  * Deploys udev keepalive rule (`99-rtl8852bu-bluetooth.rules`) preventing aggressive USB autosuspend and disconnects.

---

## 2. Power Profiles & Chassis Scaling

The power profile daemon (`bin/power-profile-manager`) dynamically adjusts its operations depending on the machine chassis:

| Feature | Battery (Laptops) | AC / Plugged In | Desktop (No Battery) |
| :--- | :--- | :--- | :--- |
| **CPU Governor** | `powersave` | `performance` | `performance` / `schedutil` |
| **EPP (Energy Performance Preference)** | `power` / `balance_power` | `performance` / `balance_performance` | `performance` |
| **CPU Turbo / Boost** | Disabled on battery saver | Enabled | Always Enabled |
| **Display Refresh Rate** | Scales to 60Hz via `hyprctl` | Preferred max (144Hz+) | Native preferred |
| **Battery Alert Service** | Monitored via `battery-alert.service` | Silent | Automatically disabled |

---

## 3. Dynamic User Environment Adaptation

All configuration scripts, Hyprland bindings, Quickshell services, and systemd user services are completely agnostic of user names or absolute paths:
* Hyprland Lua utilizes `os.getenv("HOME")`.
* Quickshell QML utilizes `Quickshell.env("HOME")`.
* Systemd user units utilize the `%h` home directory specifier.
* Shell scripts dynamically resolve target paths via `"$HOME"`.
* The installer runs an automated post-deployment token sweep ensuring no residue of developer paths remains.
