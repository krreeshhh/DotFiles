# Universal Hardware Detection & Driver Matrix Reference

This repository features an automated Universal Hardware Detection & Driver Engine (`install.sh`) that dynamically interrogates the system architecture, CPU microcode, GPU vendor/generation, Wi-Fi and Bluetooth chipsets, chassis type, kernel flavor, and hardware quirks to deploy the exact matching driver and configuration stack on any Arch Linux machine.

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

### D. Universal Wi-Fi Drivers & Firmware Suite
The engine scans PCI (`lspci -nnk`) and USB (`lsusb`) buses for all 802.11 wireless adapters:
* **Complete Vendor Firmware Suite:** Automatically installs all vendor firmware subpackages:
  * `linux-firmware` (Default base firmware)
  * `linux-firmware-realtek` (Realtek rtw88, rtw89, rtl8xxx)
  * `linux-firmware-intel` (Intel iwlwifi AX200, AX210, BE200, AC 9260)
  * `linux-firmware-mediatek` (MediaTek mt7921, mt7922, AMD RZ608/RZ616)
  * `linux-firmware-atheros` (Qualcomm Atheros ath9k, ath10k, ath11k, ath12k)
  * `linux-firmware-broadcom` (Broadcom / Cypress wireless)
  * `linux-firmware-marvell` (Marvell Avastar 88W8897 / 88W8797)
* **Regulatory Compliance & Tools:** Installs `wireless-regdb`, `iw`, and `wpa_supplicant`.
* **Broadcom STA Driver:** Detects Broadcom chips requiring proprietary drivers (`14e4:43xx`) and installs `broadcom-wl-dkms`.
* **Wi-Fi Power Management Optimization:** Deploys `/etc/NetworkManager/conf.d/default-wifi-powersave-off.conf` (`wifi.powersave = 2`), universally eliminating latency spikes and random disconnects across all wireless hardware.
* **Realtek ASPM & D3cold Stability:** Configures `/etc/modprobe.d/rtw89.conf` (disabling ASPM L1, L1SS, CLKREQ#, and low power mode) and `/etc/udev/rules.d/99-rtl8852be-pci.rules` (preventing D3cold sleep state and runtime suspend lockups on AMD Zen PCIe root ports).

### E. Universal Bluetooth Stack & High-Resolution Audio
* **BlueZ Daemon:** Installs `bluez`, `bluez-utils`, and `bluez-hid2hci` (for dual-mode HID/HCI USB dongles).
* **Auto-Power Policy:** Ensures `AutoEnable=true` in `/etc/bluetooth/main.conf` so Bluetooth adapters power on automatically upon boot or hotplug.
* **USB Bluetooth Keepalive:** Deploys universal udev rules matching `DRIVERS=="btusb"` and vendor IDs (Realtek `0bda`, Foxconn `0489:e123`) setting `power/control="on"`, preventing USB autosuspend crashes.
* **WirePlumber Autoconnect & Dual Connectivity:** Deploys `wireplumber.conf.d/50-bluez.conf` with `bluez5.auto-connect = [ hfp_hf, hsp_hs, a2dp_sink ]`, ensuring instantaneous reconnection for multipoint dual-paired earbuds and headsets.
* **Multipoint Bluetooth Connection Tool:** Includes `bin/bluetooth-connect` for seamless command-line device scanning, pairing, and targeted connection.
* **PipeWire Bluetooth Audio Codecs:** Installs `pipewire-audio` providing high-resolution SPA codecs (LDAC, AptX, AptX-HD, AAC, LC3, SBC, SBC-XQ).
* **RFKill Unblock:** Automatically unblocks Wi-Fi and Bluetooth transmitters during installation.

### F. Audio DSP & Sound Open Firmware
* Scans PCI devices for Intel DSP / AMD ACP audio controllers:
  * Automatically installs `sof-firmware` and `alsa-ucm-conf` for modern digital microphones and multi-speaker DSP arrays.

### G. Vendor-Specific Platform Quirks
* **ASUS TUF / ROG Laptops:**
  * Detects ASUS DMI product / chassis strings
  * Deploys `asusctl`, `supergfxctl`, and white keyboard backlight persistence service (`asus-kbd-white.service`).

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
