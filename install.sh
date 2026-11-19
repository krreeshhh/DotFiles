#!/usr/bin/env bash
# ==============================================================================
# Universal Arch Linux + Hyprland Dotfiles Setup & Intelligent Hardware Launcher
# ==============================================================================
# Target: Any Arch Linux system regardless of CPU, GPU, chassis, or bootloader.
# Capabilities:
#   - Automatic Hardware & Driver Probing (CPU, GPU, Audio DSP, Chassis, Quirks)
#   - Dynamic Microcode & Matching Kernel Headers Installation
#   - Intelligent Graphics Stack (NVIDIA Open/Proprietary, AMD Radeon, Intel, VM)
#   - Dynamic User & Path Adaptation (Fully username- and home-agnostic)
#   - Hardware Quirks Engine (ASUS WMI, Realtek RTL8852, SOF Audio, Laptop vs Desktop)
#   - Beautiful Interactive Terminal Launcher & Diagnostic Summary
# ==============================================================================

set -euo pipefail

# Reconnect stdin to controlling terminal if piped (e.g. curl ... | sh)
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec </dev/tty 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# Colors & Logging Helpers
# ------------------------------------------------------------------------------
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "\n${BOLD}${CYAN}==> [STEP ${1}] ${2}${NC}"; }
log_substep() { echo -e "  ${MAGENTA}→${NC} $*"; }

# ------------------------------------------------------------------------------
# Paths & Global Variables
# ------------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
INSTALL_APPS="false"
FORCE_SWAP="false"
DRY_RUN="false"
CONFIGS_ONLY="false"
DRIVERS_ONLY="false"
AUR_HELPER=""

# Hardware Profile Global Variables
CPU_VENDOR=""
CPU_MODEL=""
CPU_MICROCODE=""
KERNEL_RELEASE=""
KERNEL_HEADERS=""
CHASSIS_TYPE=""
HAS_BATTERY="false"
HAS_NVIDIA="false"
NVIDIA_MODEL=""
NVIDIA_OPEN_SUPPORTED="false"
HAS_AMD_GPU="false"
AMD_GPU_MODEL=""
HAS_INTEL_GPU="false"
INTEL_GPU_MODEL=""
IS_VM="false"
VM_TYPE=""
HAS_SOF_AUDIO="false"
HAS_ASUS_HARDWARE="false"
HAS_WIFI="false"
WIFI_MODEL=""
WIFI_VENDOR=""
WIFI_DRIVER=""
HAS_REALTEK_WIFI="false"
HAS_BROADCOM_WIFI="false"
HAS_BROADCOM_STA="false"
HAS_INTEL_WIFI="false"
HAS_MEDIATEK_WIFI="false"
HAS_ATHEROS_WIFI="false"
HAS_BLUETOOTH="false"
BT_MODEL=""
BT_VENDOR=""
BT_DRIVER=""
HAS_REALTEK_BT="false"
HAS_INTEL_BT="false"
HAS_BROADCOM_BT="false"
HAS_MEDIATEK_BT="false"
HAS_ATHEROS_BT="false"
BOOTLOADER_TYPE=""

# ------------------------------------------------------------------------------
# Pre-Flight Checks
# ------------------------------------------------------------------------------
check_arch_linux() {
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect Linux distribution. /etc/os-release not found."
        exit 1
    fi
    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *"arch"* ]]; then
        log_error "This dotfiles installer is built exclusively for Arch Linux (detected: ${NAME:-Unknown})."
        exit 1
    fi
    log_success "Verified Arch Linux environment (${NAME:-Arch Linux})."
}

ensure_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run install.sh directly as root or sudo."
        log_info "Run it as your normal user. The script will request sudo credentials when needed."
        exit 1
    fi

    if sudo -n true 2>/dev/null; then
        log_success "Sudo credentials active."
        return 0
    fi

    log_info "Authenticating sudo credentials..."
    if [ -n "${SUDO_ASKPASS:-}" ]; then
        sudo -A -v || {
            log_error "Sudo authentication failed. Exiting."
            exit 1
        }
    else
        sudo -v || {
            log_error "Sudo authentication failed. Exiting."
            exit 1
        }
    fi

    # Keep sudo timestamp alive during installer execution
    (while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill -9 "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

# ------------------------------------------------------------------------------
# AUR Helper Detection & Bootstrap
# ------------------------------------------------------------------------------
detect_or_install_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    elif command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    else
        log_warn "No AUR helper (yay or paru) detected. Bootstrapping yay-bin..."
        sudo pacman -S --needed --noconfirm base-devel git
        local tmp_yay="/tmp/yay-bin-bootstrap"
        rm -rf "$tmp_yay"
        git clone https://aur.archlinux.org/yay-bin.git "$tmp_yay"
        (cd "$tmp_yay" && makepkg -si --noconfirm)
        rm -rf "$tmp_yay"
        AUR_HELPER="yay"
    fi
    log_success "Using AUR helper: ${BOLD}${AUR_HELPER}${NC}"
}

# ------------------------------------------------------------------------------
# Package Installation Helpers
# ------------------------------------------------------------------------------
install_pacman_packages_from_file() {
    local file="$1"
    local desc="$2"
    if [ ! -f "$file" ]; then
        log_warn "Package file $file not found. Skipping."
        return 0
    fi

    log_info "Checking pacman packages from: ${desc}..."
    mapfile -t raw_pkgs < <(grep -v -E '^\s*#|^\s*$' "$file")

    if [ "${#raw_pkgs[@]}" -eq 0 ]; then
        return 0
    fi

    local needed_pkgs=()
    for pkg in "${raw_pkgs[@]}"; do
        if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
            needed_pkgs+=("$pkg")
        fi
    done

    if [ "${#needed_pkgs[@]}" -eq 0 ]; then
        log_success "All ${#raw_pkgs[@]} packages in ${desc} are already installed."
        return 0
    fi

    log_substep "Installing ${#needed_pkgs[@]} missing packages via pacman: ${needed_pkgs[*]}"
    if ! sudo pacman -S --needed --noconfirm "${needed_pkgs[@]}"; then
        log_warn "Bulk pacman installation encountered errors. Retrying packages individually..."
        for pkg in "${needed_pkgs[@]}"; do
            if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm "$pkg" || log_warn "Failed to install '$pkg'. Skipping."
            fi
        done
    fi
}

install_aur_packages_from_file() {
    local file="$1"
    local desc="$2"
    if [ ! -f "$file" ]; then
        log_warn "AUR package file $file not found. Skipping."
        return 0
    fi

    detect_or_install_aur_helper

    log_info "Checking AUR packages from: ${desc}..."
    mapfile -t raw_pkgs < <(grep -v -E '^\s*#|^\s*$' "$file")

    if [ "${#raw_pkgs[@]}" -eq 0 ]; then
        return 0
    fi

    local needed_pkgs=()
    for pkg in "${raw_pkgs[@]}"; do
        if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
            needed_pkgs+=("$pkg")
        fi
    done

    if [ "${#needed_pkgs[@]}" -eq 0 ]; then
        log_success "All ${#raw_pkgs[@]} packages in ${desc} are already installed."
        return 0
    fi

    log_substep "Installing ${#needed_pkgs[@]} missing packages via ${AUR_HELPER}: ${needed_pkgs[*]}"
    if ! "$AUR_HELPER" -S --needed --noconfirm "${needed_pkgs[@]}"; then
        log_warn "Bulk AUR installation encountered errors. Retrying individually..."
        for pkg in "${needed_pkgs[@]}"; do
            if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
                "$AUR_HELPER" -S --needed --noconfirm "$pkg" || log_warn "Failed to install '$pkg' via AUR. Skipping."
            fi
        done
    fi
}

# ------------------------------------------------------------------------------
# Intelligent Hardware & Driver Auto-Detection Engine
# ------------------------------------------------------------------------------
detect_system_hardware() {
    # 1. CPU & Microcode
    CPU_VENDOR=$(lscpu 2>/dev/null | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2}' || echo "Unknown")
    CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2}' || echo "Unknown CPU")

    case "$CPU_VENDOR" in
        AuthenticAMD)
            CPU_MICROCODE="amd-ucode"
            ;;
        GenuineIntel)
            CPU_MICROCODE="intel-ucode"
            ;;
        *)
            CPU_MICROCODE=""
            ;;
    esac

    # 2. Kernel & Matching Headers
    KERNEL_RELEASE="$(uname -r)"
    case "$KERNEL_RELEASE" in
        *-lts*)
            KERNEL_HEADERS="linux-lts-headers"
            ;;
        *-zen*)
            KERNEL_HEADERS="linux-zen-headers"
            ;;
        *-hardened*)
            KERNEL_HEADERS="linux-hardened-headers"
            ;;
        *)
            KERNEL_HEADERS="linux-headers"
            ;;
    esac

    # 3. Chassis & Power
    CHASSIS_TYPE="$(hostnamectl chassis 2>/dev/null || cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "unknown")"
    if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        HAS_BATTERY="true"
        [ "$CHASSIS_TYPE" = "unknown" ] && CHASSIS_TYPE="laptop"
    else
        HAS_BATTERY="false"
        [ "$CHASSIS_TYPE" = "unknown" ] && CHASSIS_TYPE="desktop"
    fi

    # 4. Virtual Machine Detection
    if systemd-detect-virt -q 2>/dev/null; then
        IS_VM="true"
        VM_TYPE="$(systemd-detect-virt 2>/dev/null || echo "vm")"
    else
        IS_VM="false"
        VM_TYPE="none"
    fi

    # 5. Graphics Hardware (PCI bus probe)
    local pci_display
    pci_display="$(lspci -nnk 2>/dev/null | grep -Ei "vga|3d|display" || true)"

    # NVIDIA Probing
    if echo "$pci_display" | grep -iq "10de"; then
        HAS_NVIDIA="true"
        NVIDIA_MODEL="$(echo "$pci_display" | grep -i "10de" | head -n 1 | sed -E 's/.*: //')"
        # Test for Turing (GA1xx, TU1xx), Ampere (GA10x), Ada Lovelace (AD10x), Blackwell (GB20x), or RTX/GTX 16 series
        if echo "$NVIDIA_MODEL" | grep -Eiq "RTX|GTX 16|GA1|AD1|TU1|GH1|GB2|TITAN RTX|T4|A100|A10|A16|A30|A40"; then
            NVIDIA_OPEN_SUPPORTED="true"
        else
            NVIDIA_OPEN_SUPPORTED="false"
        fi
    else
        HAS_NVIDIA="false"
        NVIDIA_MODEL=""
        NVIDIA_OPEN_SUPPORTED="false"
    fi

    # AMD GPU Probing
    if echo "$pci_display" | grep -iq "1002"; then
        HAS_AMD_GPU="true"
        AMD_GPU_MODEL="$(echo "$pci_display" | grep -i "1002" | head -n 1 | sed -E 's/.*: //')"
    else
        HAS_AMD_GPU="false"
        AMD_GPU_MODEL=""
    fi

    # Intel GPU Probing
    if echo "$pci_display" | grep -iq "8086"; then
        HAS_INTEL_GPU="true"
        INTEL_GPU_MODEL="$(echo "$pci_display" | grep -i "8086" | head -n 1 | sed -E 's/.*: //')"
    else
        HAS_INTEL_GPU="false"
        INTEL_GPU_MODEL=""
    fi

    # 6. Audio DSP (SOF / ACP)
    if lspci 2>/dev/null | grep -Eiq "Audio Coprocessor|SoundWire|SOF|Rembrandt.*Audio|Intel.*cAVS|Intel.*Smart Sound"; then
        HAS_SOF_AUDIO="true"
    else
        HAS_SOF_AUDIO="false"
    fi

    # 7. Hardware Quirks & Vendor Profiles
    local dmi_vendor
    dmi_vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")"
    if [ -d /sys/devices/platform/asus-nb-wmi ] || echo "$dmi_vendor" | grep -iq "ASUSTeK"; then
        HAS_ASUS_HARDWARE="true"
    else
        HAS_ASUS_HARDWARE="false"
    fi

    # 7. Wi-Fi & Wireless Network Controllers
    local pci_wifi usb_wifi
    pci_wifi="$(lspci -nnk 2>/dev/null | grep -iA 3 -E 'network controller|wireless|wi-fi|802\.11' || true)"
    usb_wifi="$(lsusb 2>/dev/null | grep -iE 'wireless|802\.11|wifi|wlan' || true)"

    if [ -n "$pci_wifi" ] || [ -n "$usb_wifi" ] || [ -d /sys/class/net/wlan0 ] || compgen -G "/sys/class/net/wl*" >/dev/null 2>&1; then
        HAS_WIFI="true"
        if [ -n "$pci_wifi" ]; then
            WIFI_MODEL="$(echo "$pci_wifi" | grep -m1 -i "Network controller" | sed -E 's/^[0-9a-f:.]+ Network controller \[[0-9a-f]+\]: //; s/ \[.*//')"
            [ -z "$WIFI_MODEL" ] && WIFI_MODEL="$(echo "$pci_wifi" | grep -m1 -iE 'wireless|wi-fi' | sed -E 's/^[0-9a-f:.]+ //; s/ \[.*//')"
            WIFI_DRIVER="$(echo "$pci_wifi" | grep -m1 -i "Kernel driver in use:" | sed 's/.*Kernel driver in use: //')"
        elif [ -n "$usb_wifi" ]; then
            WIFI_MODEL="$(echo "$usb_wifi" | head -n1 | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID [0-9a-f:]+ //')"
            WIFI_DRIVER="usb"
        else
            WIFI_MODEL="Generic 802.11 Wireless Interface"
            WIFI_DRIVER="cfg80211"
        fi

        # Check vendor families
        if echo "$pci_wifi $usb_wifi" | grep -iqE '10ec:|Realtek'; then
            HAS_REALTEK_WIFI="true"
            WIFI_VENDOR="Realtek"
        elif echo "$pci_wifi $usb_wifi" | grep -iqE '14e4:|Broadcom'; then
            HAS_BROADCOM_WIFI="true"
            WIFI_VENDOR="Broadcom"
            if echo "$pci_wifi" | grep -iqE '14e4:43[0-9a-f]{2}'; then
                HAS_BROADCOM_STA="true"
            fi
        elif echo "$pci_wifi $usb_wifi" | grep -iqE '8086:|Intel'; then
            HAS_INTEL_WIFI="true"
            WIFI_VENDOR="Intel"
        elif echo "$pci_wifi $usb_wifi" | grep -iqE '14c3:|1814:|MediaTek|Ralink|RZ608|RZ616|MT79'; then
            HAS_MEDIATEK_WIFI="true"
            WIFI_VENDOR="MediaTek"
        elif echo "$pci_wifi $usb_wifi" | grep -iqE '168c:|17cb:|Qualcomm|Atheros'; then
            HAS_ATHEROS_WIFI="true"
            WIFI_VENDOR="Qualcomm/Atheros"
        elif echo "$pci_wifi $usb_wifi" | grep -iqE '1b4b:|Marvell'; then
            WIFI_VENDOR="Marvell"
        else
            WIFI_VENDOR="Standard"
        fi
    else
        HAS_WIFI="false"
        WIFI_MODEL="No Wi-Fi Controller (Ethernet only)"
        WIFI_VENDOR="None"
    fi

    # 8. Bluetooth Controllers
    local usb_bt pci_bt
    usb_bt="$(lsusb 2>/dev/null | grep -iE 'bluetooth|btusb|0489:e123|0489:e102|0bda:' || true)"
    pci_bt="$(lspci -nnk 2>/dev/null | grep -iA 2 'bluetooth' || true)"

    if [ -n "$usb_bt" ] || [ -n "$pci_bt" ] || [ -d /sys/class/bluetooth ] || { command -v rfkill >/dev/null 2>&1 && rfkill list bluetooth 2>/dev/null | grep -iq bluetooth; }; then
        HAS_BLUETOOTH="true"
        if [ -n "$usb_bt" ]; then
            BT_MODEL="$(echo "$usb_bt" | head -n1 | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID [0-9a-f:]+ //')"
            BT_DRIVER="btusb"
        elif [ -n "$pci_bt" ]; then
            BT_MODEL="$(echo "$pci_bt" | grep -m1 -i "Bluetooth" | sed -E 's/^[0-9a-f:.]+ //; s/ \[.*//')"
            BT_DRIVER="$(echo "$pci_bt" | grep -m1 -i "Kernel driver in use:" | sed 's/.*Kernel driver in use: //')"
        else
            BT_MODEL="Generic Bluetooth HCI Adapter"
            BT_DRIVER="bluez"
        fi

        # Check vendor families
        if echo "$usb_bt $pci_bt" | grep -iqE '0bda:|0489:e123|0489:e102|Realtek'; then
            HAS_REALTEK_BT="true"
            BT_VENDOR="Realtek"
        elif echo "$usb_bt $pci_bt" | grep -iqE '8087:|Intel'; then
            HAS_INTEL_BT="true"
            BT_VENDOR="Intel"
        elif echo "$usb_bt $pci_bt" | grep -iqE '0489:e0e2|0e8d:|MediaTek'; then
            HAS_MEDIATEK_BT="true"
            BT_VENDOR="MediaTek"
        elif echo "$usb_bt $pci_bt" | grep -iqE '0a5c:|Broadcom'; then
            HAS_BROADCOM_BT="true"
            BT_VENDOR="Broadcom"
        elif echo "$usb_bt $pci_bt" | grep -iqE '0cf3:|Qualcomm|Atheros'; then
            HAS_ATHEROS_BT="true"
            BT_VENDOR="Qualcomm/Atheros"
        else
            BT_VENDOR="Standard"
        fi
    else
        HAS_BLUETOOTH="false"
        BT_MODEL="No Bluetooth Controller"
        BT_VENDOR="None"
    fi

    # 9. Bootloader Detection
    if [ -f /etc/default/grub ] || [ -d /boot/grub ]; then
        BOOTLOADER_TYPE="GRUB"
    elif [ -d /boot/loader/entries ] || [ -f /boot/loader/loader.conf ]; then
        BOOTLOADER_TYPE="systemd-boot"
    elif [ -f /boot/limine.cfg ] || [ -d /boot/EFI/limine ]; then
        BOOTLOADER_TYPE="Limine"
    else
        BOOTLOADER_TYPE="EFISTUB/Other"
    fi
}

print_hardware_report() {
    detect_system_hardware

    echo -e "${BOLD}${CYAN}+-----------------------------------------------------------------------------+${NC}"
    echo -e "${BOLD}${CYAN}|            ARCH LINUX UNIVERSAL HARDWARE & DRIVER DIAGNOSTICS               |${NC}"
    echo -e "${BOLD}${CYAN}+-----------------------------------------------------------------------------+${NC}"
    printf "${BOLD}| Host Platform  :${NC} %-56s |\n" "$(hostname 2>/dev/null || echo "ArchLinux") (${KERNEL_RELEASE})"
    printf "${BOLD}| CPU Model      :${NC} %-56s |\n" "${CPU_MODEL:0:43} [${CPU_VENDOR:0:9}]"
    printf "${BOLD}| CPU Microcode  :${NC} %-56s |\n" "${CPU_MICROCODE:-None required / Virtualized}"
    printf "${BOLD}| Kernel Headers :${NC} %-56s |\n" "${KERNEL_HEADERS}"
    printf "${BOLD}| Chassis Type   :${NC} %-56s |\n" "${CHASSIS_TYPE^} ($([ "$HAS_BATTERY" = "true" ] && echo "Battery active" || echo "AC Desktop/VM"))"

    # GPU Probing Display
    if [ "$HAS_NVIDIA" = "true" ]; then
        local nv_driver="nvidia-dkms (Proprietary)"
        [ "$NVIDIA_OPEN_SUPPORTED" = "true" ] && nv_driver="nvidia-open-dkms (Turing+ Open)"
        printf "${BOLD}| NVIDIA GPU     :${NC} %-56s |\n" "${NVIDIA_MODEL:0:30} [${nv_driver}]"
    fi
    if [ "$HAS_AMD_GPU" = "true" ]; then
        printf "${BOLD}| AMD GPU        :${NC} %-56s |\n" "${AMD_GPU_MODEL:0:32} [Mesa/Vulkan-Radeon]"
    fi
    if [ "$HAS_INTEL_GPU" = "true" ]; then
        printf "${BOLD}| Intel GPU      :${NC} %-56s |\n" "${INTEL_GPU_MODEL:0:32} [Mesa/Vulkan-Intel/iHD]"
    fi
    if [ "$IS_VM" = "true" ]; then
        printf "${BOLD}| Virtual GPU    :${NC} %-56s |\n" "Hypervisor Virtual Graphics (${VM_TYPE})"
    fi
    if [ "$HAS_NVIDIA" = "false" ] && [ "$HAS_AMD_GPU" = "false" ] && [ "$HAS_INTEL_GPU" = "false" ] && [ "$IS_VM" = "false" ]; then
        printf "${BOLD}| Graphics/GPU   :${NC} %-56s |\n" "Standard Display Adapter (Mesa/KMS llvmpipe)"
    fi

    # Wi-Fi Probing Display
    if [ "$HAS_WIFI" = "true" ]; then
        local wf_drv="${WIFI_DRIVER:-cfg80211}"
        printf "${BOLD}| Wi-Fi Adapter  :${NC} %-56s |\n" "${WIFI_MODEL:0:36} [${WIFI_VENDOR}/${wf_drv}]"
    else
        printf "${BOLD}| Wi-Fi Adapter  :${NC} %-56s |\n" "None detected (Wired Ethernet)"
    fi

    # Bluetooth Probing Display
    if [ "$HAS_BLUETOOTH" = "true" ]; then
        local bt_drv="${BT_DRIVER:-btusb}"
        printf "${BOLD}| Bluetooth Radio:${NC} %-56s |\n" "${BT_MODEL:0:36} [${BT_VENDOR}/${bt_drv}]"
    else
        printf "${BOLD}| Bluetooth Radio:${NC} %-56s |\n" "None detected / Inactive"
    fi

    # Hardware Quirks Display
    local quirk_items=()
    [ "$HAS_ASUS_HARDWARE" = "true" ] && quirk_items+=("ASUS TUF/ROG Platform WMI")
    [ "$HAS_REALTEK_WIFI" = "true" ] && quirk_items+=("Realtek Wi-Fi (rtw89/rtw88 ASPM & powersave fix)")
    [ "$HAS_BROADCOM_STA" = "true" ] && quirk_items+=("Broadcom BCM43xx STA Driver (broadcom-wl-dkms)")
    [ "$HAS_BLUETOOTH" = "true" ] && quirk_items+=("Universal USB Bluetooth Keepalive (btusb / AutoEnable)")
    [ "$HAS_SOF_AUDIO" = "true" ] && quirk_items+=("Sound Open Firmware / Audio DSP")

    if [ "${#quirk_items[@]}" -eq 0 ]; then
        printf "${BOLD}| System Quirks  :${NC} %-56s |\n" "Standard Architecture (No platform quirks required)"
    else
        printf "${BOLD}| System Quirks  :${NC} %-56s |\n" "${quirk_items[0]}"
        for ((q=1; q<${#quirk_items[@]}; q++)); do
            printf "${BOLD}|                :${NC} %-56s |\n" "${quirk_items[$q]}"
        done
    fi

    printf "${BOLD}| Bootloader     :${NC} %-56s |\n" "${BOOTLOADER_TYPE}"
    echo -e "${BOLD}${CYAN}+-----------------------------------------------------------------------------+${NC}"
    echo
}

# ------------------------------------------------------------------------------
# Hardware Driver & Platform Configuration Engine
# ------------------------------------------------------------------------------
install_and_configure_drivers() {
    log_step "2/9" "Installing Auto-Detected Hardware Drivers & Microcode"
    detect_system_hardware

    local driver_pkgs=()

    # 1. CPU Microcode
    if [ -n "$CPU_MICROCODE" ]; then
        log_substep "Selected CPU microcode: ${CPU_MICROCODE}"
        driver_pkgs+=("$CPU_MICROCODE")
    fi

    # 2. Kernel Headers, DKMS & Universal Firmware Suite
    log_substep "Selected kernel build headers: ${KERNEL_HEADERS}"
    driver_pkgs+=(
        "$KERNEL_HEADERS"
        "base-devel"
        "dkms"
        "linux-firmware"
        "linux-firmware-atheros"
        "linux-firmware-broadcom"
        "linux-firmware-intel"
        "linux-firmware-marvell"
        "linux-firmware-mediatek"
        "linux-firmware-realtek"
        "wireless-regdb"
        "iw"
        "wpa_supplicant"
        "bluez"
        "bluez-utils"
        "bluez-hid2hci"
        "pipewire-audio"
    )

    # Broadcom STA Wireless Driver
    if [ "$HAS_BROADCOM_STA" = "true" ]; then
        log_substep "Broadcom BCM43xx STA wireless chipset detected: adding broadcom-wl-dkms..."
        driver_pkgs+=("broadcom-wl-dkms")
    fi

    # 3. Audio DSP Firmware
    if [ "$HAS_SOF_AUDIO" = "true" ]; then
        log_substep "Detected Sound Open Firmware / Audio DSP: adding sof-firmware and alsa-firmware"
        driver_pkgs+=("sof-firmware" "alsa-firmware")
    fi

    # 4. Graphics Drivers
    # NVIDIA
    if [ "$HAS_NVIDIA" = "true" ]; then
        if [ "$NVIDIA_OPEN_SUPPORTED" = "true" ]; then
            log_substep "Configuring NVIDIA GPU with Open Kernel Module (Turing+ generation): nvidia-open-dkms"
            driver_pkgs+=("nvidia-open-dkms" "nvidia-utils" "libva-nvidia-driver")
        else
            log_substep "Configuring NVIDIA GPU with Proprietary Driver (Pre-Turing legacy architecture): nvidia-dkms"
            driver_pkgs+=("nvidia-dkms" "nvidia-utils" "libva-nvidia-driver")
        fi
    fi

    # AMD Radeon / APU
    if [ "$HAS_AMD_GPU" = "true" ]; then
        log_substep "Configuring AMD Radeon graphics: mesa, vulkan-radeon, libva-mesa-driver"
        driver_pkgs+=("mesa" "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau" "xf86-video-amdgpu")
    fi

    # Intel Graphics / UHD / Iris Xe / Arc
    if [ "$HAS_INTEL_GPU" = "true" ]; then
        log_substep "Configuring Intel graphics: mesa, vulkan-intel, intel-media-driver"
        driver_pkgs+=("mesa" "vulkan-intel" "intel-media-driver")
    fi

    # Virtual Machine Guest Drivers
    if [ "$IS_VM" = "true" ]; then
        log_substep "Configuring Virtual Machine Guest Tools (${VM_TYPE})"
        case "$VM_TYPE" in
            kvm|qemu)
                driver_pkgs+=("qemu-guest-agent" "spice-vdagent" "mesa")
                ;;
            oracle)
                driver_pkgs+=("virtualbox-guest-utils" "mesa")
                ;;
            vmware)
                driver_pkgs+=("open-vm-tools" "xf86-video-vmware" "mesa")
                ;;
            *)
                driver_pkgs+=("mesa")
                ;;
        esac
    fi

    # Bulk install detected packages
    local needed_driver_pkgs=()
    for pkg in "${driver_pkgs[@]}"; do
        if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
            needed_driver_pkgs+=("$pkg")
        fi
    done

    if [ "${#needed_driver_pkgs[@]}" -gt 0 ]; then
        log_info "Installing ${#needed_driver_pkgs[@]} required driver packages via pacman..."
        sudo pacman -S --needed --noconfirm "${needed_driver_pkgs[@]}" || {
            log_warn "Some driver packages failed in bulk. Retrying individually..."
            for pkg in "${needed_driver_pkgs[@]}"; do
                sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || log_warn "Could not install driver package '$pkg'. Continuing."
            done
        }
    else
        log_success "All required hardware driver packages are already installed."
    fi

    # 5. NVIDIA System Integration
    if [ "$HAS_NVIDIA" = "true" ]; then
        log_substep "Configuring NVIDIA power management & S0ix sleep states..."

        # GRUB Parameters (if GRUB is used)
        if [ "$BOOTLOADER_TYPE" = "GRUB" ] && [ -f /etc/default/grub ]; then
            if ! grep -q "NVreg_EnableS0ixPowerManagement=1" /etc/default/grub; then
                log_substep "Adding NVIDIA S0ix and modeset parameters to /etc/default/grub..."
                sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_EnableS0ixPowerManagement=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1 nvidia.NVreg_TemporaryFilePath=\/var\/tmp nvidia_drm.modeset=1 nvidia_drm.fbdev=1"/' /etc/default/grub
                if command -v grub-mkconfig >/dev/null 2>&1; then
                    sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
                fi
            fi
        fi

        # Modprobe options
        if [ -f "$DOTFILES_DIR/system/etc/modprobe.d/nvidia.conf" ]; then
            sudo mkdir -p /etc/modprobe.d
            sudo cp "$DOTFILES_DIR/system/etc/modprobe.d/nvidia.conf" /etc/modprobe.d/nvidia.conf
        fi

        # Suspend sleep hook
        if [ -f "$DOTFILES_DIR/system/usr/lib/systemd/system-sleep/hyprland-suspend" ]; then
            sudo mkdir -p /usr/lib/systemd/system-sleep
            sudo cp "$DOTFILES_DIR/system/usr/lib/systemd/system-sleep/hyprland-suspend" /usr/lib/systemd/system-sleep/hyprland-suspend
            sudo chmod +x /usr/lib/systemd/system-sleep/hyprland-suspend
        fi

        # Early KMS in mkinitcpio
        if [ -f /etc/mkinitcpio.conf ]; then
            if ! grep -q "nvidia nvidia_modeset" /etc/mkinitcpio.conf; then
                log_substep "Adding NVIDIA early KMS modules to /etc/mkinitcpio.conf..."
                sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
                command -v mkinitcpio >/dev/null 2>&1 && sudo mkinitcpio -P || true
            fi
        fi

        # NVIDIA System Services
        log_substep "Enabling NVIDIA VRAM preservation sleep services..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

        # VA-API Environment
        if ! grep -q "LIBVA_DRIVER_NAME=nvidia" /etc/environment 2>/dev/null; then
            echo "LIBVA_DRIVER_NAME=nvidia" | sudo tee -a /etc/environment >/dev/null
        fi
    elif [ "$HAS_AMD_GPU" = "true" ] && [ "$HAS_NVIDIA" = "false" ]; then
        # Pure AMD early KMS
        if [ -f /etc/mkinitcpio.conf ] && ! grep -q "amdgpu" /etc/mkinitcpio.conf; then
            log_substep "Configuring AMDGPU early KMS in /etc/mkinitcpio.conf..."
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 amdgpu)/' /etc/mkinitcpio.conf
            command -v mkinitcpio >/dev/null 2>&1 && sudo mkinitcpio -P || true
        fi
    elif [ "$HAS_INTEL_GPU" = "true" ] && [ "$HAS_NVIDIA" = "false" ]; then
        # Pure Intel early KMS
        if [ -f /etc/mkinitcpio.conf ] && ! grep -q "i915" /etc/mkinitcpio.conf && ! grep -q "xe" /etc/mkinitcpio.conf; then
            log_substep "Configuring Intel early KMS in /etc/mkinitcpio.conf..."
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 i915)/' /etc/mkinitcpio.conf
            command -v mkinitcpio >/dev/null 2>&1 && sudo mkinitcpio -P || true
        fi
    fi

    # 6. Universal Wi-Fi & Bluetooth Stability Integration
    # Universal Wi-Fi Power Management Optimization
    log_substep "Applying Universal Wi-Fi power-save disable policy (NetworkManager)..."
    sudo mkdir -p /etc/NetworkManager/conf.d
    if [ -f "$DOTFILES_DIR/system/etc/NetworkManager/conf.d/default-wifi-powersave-off.conf" ]; then
        sudo cp "$DOTFILES_DIR/system/etc/NetworkManager/conf.d/default-wifi-powersave-off.conf" /etc/NetworkManager/conf.d/default-wifi-powersave-off.conf
    else
        echo -e "[connection]\nwifi.powersave = 2" | sudo tee /etc/NetworkManager/conf.d/default-wifi-powersave-off.conf >/dev/null
    fi
    command -v nmcli >/dev/null 2>&1 && sudo nmcli general reload 2>/dev/null || true

    # Realtek Wi-Fi ASPM & Sleep Stability Options
    if [ "$HAS_REALTEK_WIFI" = "true" ]; then
        log_substep "Applying Realtek Wi-Fi ASPM and power saving stability parameters..."
        sudo mkdir -p /etc/modprobe.d
        [ -f "$DOTFILES_DIR/system/etc/modprobe.d/rtw89.conf" ] && sudo cp "$DOTFILES_DIR/system/etc/modprobe.d/rtw89.conf" /etc/modprobe.d/rtw89.conf
        [ -f "$DOTFILES_DIR/system/etc/modprobe.d/rtw88.conf" ] && sudo cp "$DOTFILES_DIR/system/etc/modprobe.d/rtw88.conf" /etc/modprobe.d/rtw88.conf
    fi

    # Universal Bluetooth USB Keepalive & Autosuspend Protection
    log_substep "Applying Universal Bluetooth USB autosuspend keepalive udev rules..."
    sudo mkdir -p /etc/udev/rules.d
    if [ -f "$DOTFILES_DIR/system/etc/udev/rules.d/99-rtl8852bu-autosuspend.rules" ]; then
        sudo cp "$DOTFILES_DIR/system/etc/udev/rules.d/99-rtl8852bu-autosuspend.rules" /etc/udev/rules.d/99-rtl8852bu-autosuspend.rules
        sudo udevadm control --reload-rules 2>/dev/null || true
        sudo udevadm trigger --subsystem-match=usb 2>/dev/null || true
    fi

    # Bluetooth AutoEnable Policy Configuration
    if [ -f /etc/bluetooth/main.conf ]; then
        log_substep "Ensuring Bluetooth AutoEnable=true in /etc/bluetooth/main.conf..."
        if grep -q "^#AutoEnable=true" /etc/bluetooth/main.conf; then
            sudo sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
        elif ! grep -q "^AutoEnable=true" /etc/bluetooth/main.conf; then
            sudo sed -i '/^\[Policy\]/a AutoEnable=true' /etc/bluetooth/main.conf 2>/dev/null || true
        fi
    elif [ -d /etc/bluetooth ]; then
        log_substep "Creating /etc/bluetooth/main.conf with AutoEnable=true..."
        echo -e "[Policy]\nAutoEnable=true" | sudo tee /etc/bluetooth/main.conf >/dev/null
    fi

    # Unblock RFKill for Wireless & Bluetooth
    command -v rfkill >/dev/null 2>&1 && {
        log_substep "Unblocking Wi-Fi and Bluetooth via rfkill..."
        sudo rfkill unblock wifi 2>/dev/null || true
        sudo rfkill unblock bluetooth 2>/dev/null || true
    }

    # ASUS WMI Keyboard Backlight
    if [ "$HAS_ASUS_HARDWARE" = "true" ]; then
        log_substep "Applying ASUS Keyboard Backlight permissions rule..."
        if [ -f "$DOTFILES_DIR/system/etc/udev/rules.d/99-asus-kbd-backlight.rules" ]; then
            sudo mkdir -p /etc/udev/rules.d
            sudo cp "$DOTFILES_DIR/system/etc/udev/rules.d/99-asus-kbd-backlight.rules" /etc/udev/rules.d/99-asus-kbd-backlight.rules
            sudo udevadm control --reload-rules 2>/dev/null || true
            sudo udevadm trigger --subsystem-match=leds 2>/dev/null || true
        fi
    fi

    # Chassis Power Switching & Battery Management
    log_substep "Configuring power-profile-manager and system power policies..."
    if [ -f "$DOTFILES_DIR/bin/power-profile-manager" ]; then
        sudo cp "$DOTFILES_DIR/bin/power-profile-manager" /usr/local/bin/power-profile-manager
        sudo chmod 0755 /usr/local/bin/power-profile-manager
    fi
    if [ -f "$DOTFILES_DIR/system/etc/sudoers.d/99-power-profile" ]; then
        sudo mkdir -p /etc/sudoers.d
        sudo cp "$DOTFILES_DIR/system/etc/sudoers.d/99-power-profile" /etc/sudoers.d/99-power-profile
        sudo chmod 0440 /etc/sudoers.d/99-power-profile
    fi

    if [ "$HAS_BATTERY" = "true" ]; then
        log_substep "Configuring laptop battery automation and lid sleep policies..."
        if [ -f "$DOTFILES_DIR/system/etc/udev/rules.d/99-power-profile.rules" ]; then
            sudo mkdir -p /etc/udev/rules.d
            sudo cp "$DOTFILES_DIR/system/etc/udev/rules.d/99-power-profile.rules" /etc/udev/rules.d/99-power-profile.rules
            sudo udevadm control --reload-rules 2>/dev/null || true
        fi
        if [ -f "$DOTFILES_DIR/system/etc/systemd/system/power-profile.service" ]; then
            sudo mkdir -p /etc/systemd/system
            sudo cp "$DOTFILES_DIR/system/etc/systemd/system/power-profile.service" /etc/systemd/system/power-profile.service
            sudo systemctl daemon-reload 2>/dev/null || true
            sudo systemctl enable --now power-profile.service 2>/dev/null || true
        fi
        if [ -f "$DOTFILES_DIR/system/etc/systemd/logind.conf.d/lid.conf" ]; then
            sudo mkdir -p /etc/systemd/logind.conf.d
            sudo cp "$DOTFILES_DIR/system/etc/systemd/logind.conf.d/lid.conf" /etc/systemd/logind.conf.d/lid.conf
        fi
    else
        log_info "Desktop system detected (no battery). Configured power-profile-manager for permanent AC mode."
    fi

    log_success "Hardware drivers and platform configuration applied successfully."
}

# ------------------------------------------------------------------------------
# System Swap Configuration
# ------------------------------------------------------------------------------
configure_swap() {
    log_step "1/9" "Configuring System Swap Space (8GB)"

    local target_swap_gb=8
    local target_swap_bytes=$(( target_swap_gb * 1024 * 1024 * 1024 ))
    local current_swap_bytes=0

    if command -v free >/dev/null 2>&1; then
        current_swap_bytes=$(free -b 2>/dev/null | awk '/^Swap:/ {print $2}')
    fi

    # Check if swap space is already active and sufficient (>= 8GB) unless forced
    if [ "${FORCE_SWAP:-false}" = "false" ] && [ -n "$current_swap_bytes" ] && [ "$current_swap_bytes" -ge "$target_swap_bytes" ]; then
        local readable_swap
        readable_swap=$(numfmt --to=iec-i --suffix=B "$current_swap_bytes" 2>/dev/null || echo "${target_swap_gb}GB")
        log_info "Swap space already active: ${readable_swap} (>= ${target_swap_gb}GB). Preserving existing swap configuration."

        if swapon --show=NAME --noheadings 2>/dev/null | grep -q "^/swapfile"; then
            if ! grep -q "^/swapfile" /etc/fstab 2>/dev/null; then
                log_substep "Adding active /swapfile to /etc/fstab for boot persistence..."
                echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
            fi
        fi
        return 0
    fi

    # Check available root filesystem disk space (need ~8.5GB free: 8912896 KB)
    local avail_kb
    avail_kb=$(df -k / 2>/dev/null | awk 'NR==2 {print $4}' || echo "99999999")
    if [ "$avail_kb" -lt 8912896 ]; then
        log_warn "Insufficient free disk space on / to allocate an 8GB swapfile (available: $(( avail_kb / 1024 ))MB). Skipping swap setup."
        return 0
    fi

    log_substep "Configuring ${target_swap_gb}GB swapfile at /swapfile..."

    if swapon --show=NAME --noheadings 2>/dev/null | grep -q "^/swapfile"; then
        log_substep "Temporarily deactivating existing /swapfile..."
        sudo swapoff /swapfile 2>/dev/null || true
    fi

    local fstype
    fstype=$(findmnt -no FSTYPE / 2>/dev/null || echo "ext4")

    if [ "$fstype" = "btrfs" ]; then
        log_substep "Detected Btrfs root filesystem. Creating Btrfs-compatible swapfile..."
        sudo rm -f /swapfile
        if command -v btrfs >/dev/null 2>&1 && btrfs filesystem mkswapfile --help >/dev/null 2>&1; then
            sudo btrfs filesystem mkswapfile --size 8g /swapfile
        else
            sudo truncate -s 0 /swapfile
            sudo chattr +C /swapfile 2>/dev/null || true
            sudo btrfs property set /swapfile compression none 2>/dev/null || true
            sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
        fi
    else
        log_substep "Allocating 8GB swapfile on ${fstype}..."
        sudo rm -f /swapfile
        if ! sudo fallocate -l 8G /swapfile 2>/dev/null; then
            log_substep "fallocate unsupported or failed, creating swapfile with dd..."
            sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
        fi
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
    fi

    log_substep "Activating 8GB swapfile..."
    sudo swapon /swapfile

    if ! grep -q "^/swapfile" /etc/fstab 2>/dev/null; then
        log_substep "Registering /swapfile in /etc/fstab..."
        echo "/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab >/dev/null
    fi

    log_success "8GB swapfile successfully created, activated, and registered in /etc/fstab."
}

# ------------------------------------------------------------------------------
# Core Package Installation
# ------------------------------------------------------------------------------
install_all_packages() {
    log_step "3/9" "Installing Base Hyprland Stack & Core System Packages"
    if [ -f "$DOTFILES_DIR/scripts/hyprland.sh" ]; then
        log_substep "Running foundational Hyprland setup script (scripts/hyprland.sh)..."
        bash "$DOTFILES_DIR/scripts/hyprland.sh" --non-interactive
    fi

    log_substep "Installing extended dotfiles runtime packages..."
    install_pacman_packages_from_file "$DOTFILES_DIR/packages/pacman-runtime.txt" "Pacman Runtime Packages"
    install_pacman_packages_from_file "$DOTFILES_DIR/packages/fonts.txt" "Font Packages"

    log_step "4/9" "Installing AUR Desktop, Theming & Launcher Packages"
    detect_or_install_aur_helper
    install_aur_packages_from_file "$DOTFILES_DIR/packages/aur-runtime.txt" "AUR Runtime Packages"

    if [ "$INSTALL_APPS" = "true" ]; then
        log_step "4b" "Installing Optional Desktop Applications & Tools"
        install_pacman_packages_from_file "$DOTFILES_DIR/packages/pacman-optional.txt" "Pacman Optional Apps"
        install_aur_packages_from_file "$DOTFILES_DIR/packages/aur-optional.txt" "AUR Optional Apps & Tools"
    fi
}

# ------------------------------------------------------------------------------
# System Services Configuration
# ------------------------------------------------------------------------------
configure_system_services() {
    log_step "5/9" "Enabling Required System & User Services"
    detect_system_hardware

    # Universal System Services
    local sys_services=("sddm.service" "NetworkManager.service" "bluetooth.service" "ntpd.service" "udisks2.service" "usbmuxd.service")
    for srv in "${sys_services[@]}"; do
        log_substep "Enabling system service: ${srv}"
        sudo systemctl enable "$srv" 2>/dev/null || true
    done

    # Universal User Services
    local user_services=("pipewire.service" "pipewire-pulse.service" "wireplumber.service" "hypr-pip-helper.service" "quickshell.service" "hypridle.service")

    # Conditionally enable hardware-specific user services
    if [ "$HAS_BATTERY" = "true" ]; then
        user_services+=("battery-alert.service")
    fi
    if [ "$HAS_ASUS_HARDWARE" = "true" ] && [ -d /sys/class/leds/asus::kbd_backlight ]; then
        user_services+=("asus-kbd-white.service")
    fi

    for srv in "${user_services[@]}"; do
        log_substep "Enabling user service: ${srv}"
        systemctl --user enable "$srv" 2>/dev/null || true
    done
}

# ------------------------------------------------------------------------------
# Deploy Configurations, Binaries & Assets
# ------------------------------------------------------------------------------
deploy_dotfiles() {
    log_step "6/9" "Deploying Configuration Files, Standalone Binaries & Assets"

    # 1. Create Target Directory Tree
    log_substep "Creating user directory structure..."
    mkdir -p "$HOME"/{.config,.local/bin,.local/lib,.wallpaper,Pictures/Screenshots,Pictures/Wallpapers}

    # 2. Deploy Configurations from config/
    log_substep "Deploying ~/.config application trees..."
    local config_dirs=("hypr" "quickshell" "dunst" "DotFiles" "ghostty" "yazi" "clipse" "gtk-3.0" "gtk-4.0" "environment.d" "herdr" "matugen" "dotfiles")
    for d in "${config_dirs[@]}"; do
        if [ -d "$DOTFILES_DIR/config/$d" ]; then
            if [ -d "$HOME/.config/$d" ]; then
                mkdir -p "$BACKUP_DIR"
                cp -r "$HOME/.config/$d" "$BACKUP_DIR/"
            fi
            cp -r "$DOTFILES_DIR/config/$d" "$HOME/.config/"
        fi
    done

    # Ensure Quickshell QML internal module symlinks exist
    ln -sf "$HOME/.config/quickshell/qs/Commons" "$HOME/.config/quickshell/Commons" 2>/dev/null || true
    ln -sf "$HOME/.config/quickshell/qs/Ui" "$HOME/.config/quickshell/Ui" 2>/dev/null || true

    # Deploy Systemd user services
    if [ -d "$DOTFILES_DIR/config/systemd/user" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -r --remove-destination "$DOTFILES_DIR/config/systemd/user/"* "$HOME/.config/systemd/user/" 2>/dev/null || true
    fi

    # Deploy Autostart entries
    if [ -d "$DOTFILES_DIR/config/autostart" ]; then
        mkdir -p "$HOME/.config/autostart"
        cp -r "$DOTFILES_DIR/config/autostart/"* "$HOME/.config/autostart/" 2>/dev/null || true
    fi

    # Deploy single config files
    [ -f "$DOTFILES_DIR/config/kdeglobals" ] && cp "$DOTFILES_DIR/config/kdeglobals" "$HOME/.config/"
    [ -f "$DOTFILES_DIR/config/mimeapps.list" ] && cp "$DOTFILES_DIR/config/mimeapps.list" "$HOME/.config/"
    [ -f "$DOTFILES_DIR/config/gtkrc-2.0" ] && cp "$DOTFILES_DIR/config/gtkrc-2.0" "$HOME/.gtkrc-2.0"

    # Deploy bash profile if not present
    if [ -f "$DOTFILES_DIR/home/.bashrc" ] && [ ! -f "$HOME/.bashrc" ]; then
        cp "$DOTFILES_DIR/home/.bashrc" "$HOME/.bashrc"
    fi
    if [ -f "$DOTFILES_DIR/home/.bash_profile" ] && [ ! -f "$HOME/.bash_profile" ]; then
        cp "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
    fi

    # Deploy Antigravity agent skills, rules & mechanic configs
    if [ -d "$DOTFILES_DIR/home/.agents" ]; then
        log_substep "Deploying Antigravity mechanic skill, agent rules & configs..."
        mkdir -p "$HOME/.agents"
        cp -r "$DOTFILES_DIR/home/.agents/"* "$HOME/.agents/" 2>/dev/null || true
        [ -f "$DOTFILES_DIR/home/.agents/.skill-lock.json" ] && cp "$DOTFILES_DIR/home/.agents/.skill-lock.json" "$HOME/.agents/" 2>/dev/null || true
    fi

    # 3. Deploy Standalone Binaries
    log_substep "Deploying custom binaries to ~/.local/bin/..."
    if [ -d "$DOTFILES_DIR/bin" ]; then
        cp -r "$DOTFILES_DIR/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
        chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
    fi

    # Deploy system-wide binaries
    if [ -f "$DOTFILES_DIR/bin/patch-hyprland-blur" ]; then
        sudo cp "$DOTFILES_DIR/bin/patch-hyprland-blur" /usr/local/bin/patch-hyprland-blur
        sudo chmod 0755 /usr/local/bin/patch-hyprland-blur
    fi
    if [ -f "$DOTFILES_DIR/bin/power-profile-manager" ]; then
        sudo cp "$DOTFILES_DIR/bin/power-profile-manager" /usr/local/bin/power-profile-manager
        sudo chmod 0755 /usr/local/bin/power-profile-manager
    fi

    # Ensure swww compatibility symlinks exist
    ln -sf "$HOME/.local/bin/awww" "$HOME/.local/bin/swww" 2>/dev/null || true
    ln -sf "$HOME/.local/bin/awww-daemon" "$HOME/.local/bin/swww-daemon" 2>/dev/null || true

    # Deploy local libraries
    if [ -d "$DOTFILES_DIR/lib" ]; then
        cp -P "$DOTFILES_DIR/lib/"* "$HOME/.local/lib/" 2>/dev/null || true
    fi

    # 4. Deploy Wallpapers, Fonts, Icons & Assets
    log_substep "Deploying wallpapers to ~/.wallpaper/ and ~/Pictures/Wallpapers/..."
    if [ -d "$DOTFILES_DIR/assets/wallpapers" ]; then
        mkdir -p "$HOME/.wallpaper" "$HOME/Pictures/Wallpapers"
        cp -r "$DOTFILES_DIR/assets/wallpapers/"* "$HOME/.wallpaper/" 2>/dev/null || true
        cp -r "$DOTFILES_DIR/assets/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
    fi

    log_substep "Deploying webapp icons and custom desktop launchers..."
    if [ -d "$DOTFILES_DIR/assets/share/icons" ]; then
        mkdir -p "$HOME/.local/share/icons"
        cp -r "$DOTFILES_DIR/assets/share/icons/"* "$HOME/.local/share/icons/" 2>/dev/null || true
    fi
    if [ -d "$DOTFILES_DIR/assets/share/applications" ]; then
        mkdir -p "$HOME/.local/share/applications"
        cp -r "$DOTFILES_DIR/assets/share/applications/"* "$HOME/.local/share/applications/" 2>/dev/null || true
        command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi

    log_substep "Deploying Universal Picture-in-Picture browser extension..."
    if [ -d "$DOTFILES_DIR/assets/hypr-pip" ]; then
        mkdir -p "$HOME/.local/share/hypr-pip"
        cp -r "$DOTFILES_DIR/assets/hypr-pip/"* "$HOME/.local/share/hypr-pip/" 2>/dev/null || true
    fi

    local ext_path="$HOME/.local/share/hypr-pip/extension"
    if [ -d "$ext_path" ]; then
        log_substep "Configuring Picture-in-Picture extension for Chromium-based browsers..."
        for flag_file in \
            "$HOME/.config/brave-origin-flags.conf" \
            "$HOME/.config/brave-flags.conf" \
            "$HOME/.config/chromium-flags.conf" \
            "$HOME/.config/chrome-flags.conf" \
            "$HOME/.config/helium-flags.conf"; do

            mkdir -p "$(dirname "$flag_file")"
            if [ -f "$flag_file" ]; then
                if ! grep -q -- "--load-extension=" "$flag_file"; then
                    echo "--load-extension=$ext_path" >> "$flag_file"
                elif ! grep -q "$ext_path" "$flag_file"; then
                    sed -i "s|--load-extension=\([^ ]*\)|--load-extension=\1,$ext_path|" "$flag_file"
                fi
            else
                echo "--load-extension=$ext_path" > "$flag_file"
            fi
        done
    fi

    log_substep "Deploying custom system and user fonts..."
    if [ -d "$DOTFILES_DIR/assets/fonts" ]; then
        mkdir -p "$HOME/.local/share/fonts"
        cp -r "$DOTFILES_DIR/assets/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null || true
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            sudo mkdir -p /usr/local/share/fonts 2>/dev/null || true
            sudo cp -r "$DOTFILES_DIR/assets/fonts/"* /usr/local/share/fonts/ 2>/dev/null || true
        fi
        fc-cache -f 2>/dev/null || true
    fi

    # 5. Dynamic Username & Home Path Adaptation Sweep
    # Guarantees that any config referencing the blueprint user gets adapted to current user
    if [ "$HOME" != "/home/Krish" ]; then
        log_substep "Adapting configuration paths dynamically to ${HOME}..."
        local sweep_dirs=("$HOME/.config" "$HOME/.local")
        [ -d "$HOME/.agents" ] && sweep_dirs+=("$HOME/.agents")
        find "${sweep_dirs[@]}" -type f \( -name "*.qml" -o -name "*.json" -o -name "*.conf" -o -name "*.lua" -o -name "*.service" -o -name "*.sh" -o -name "*.py" -o -name "*.desktop" -o -name "*.md" \) \
            -exec sed -i "s|/home/Krish|${HOME}|g" {} + 2>/dev/null || true
    fi

    # 6. Set Permissions on Scripts
    log_substep "Applying executable permissions on scripts..."
    chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true
    chmod +x "$HOME/.config/DotFiles/wallpaper/"*.sh "$HOME/.config/DotFiles/wallpaper/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/DotFiles/theme/"*.sh "$HOME/.config/DotFiles/theme/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/DotFiles/launcher/"*.sh "$HOME/.config/DotFiles/launcher/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/quickshell/"*.sh "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true

    # 7. Pacman Hyprland Blur Hook
    if [ -f "$DOTFILES_DIR/system/etc/pacman.d/hooks/99-hyprland-blur.hook" ]; then
        sudo mkdir -p /etc/pacman.d/hooks
        sudo cp "$DOTFILES_DIR/system/etc/pacman.d/hooks/99-hyprland-blur.hook" /etc/pacman.d/hooks/99-hyprland-blur.hook
        if [ -x /usr/local/bin/patch-hyprland-blur ]; then
            sudo /usr/local/bin/patch-hyprland-blur 2>/dev/null || true
        fi
    fi

    # 8. Build & Install Nautilus Dynamic Theme Reloader Extension (if GCC present)
    if [ -d "$HOME/.config/DotFiles/theme/nautilus-extension" ] && command -v gcc >/dev/null 2>&1; then
        log_substep "Compiling and installing Nautilus Dynamic Theme Reloader extension..."
        (
            cd "$HOME/.config/DotFiles/theme/nautilus-extension"
            make clean >/dev/null 2>&1 || true
            make >/dev/null 2>&1 || true
            if [ -f "libnautilus-theme-reloader.so" ]; then
                sudo mkdir -p /usr/lib/nautilus/extensions-4
                sudo cp -f libnautilus-theme-reloader.so /usr/lib/nautilus/extensions-4/libnautilus-theme-reloader.so
                sudo chmod 755 /usr/lib/nautilus/extensions-4/libnautilus-theme-reloader.so
            fi
        ) || log_warn "Could not automatically compile Nautilus theme reloader extension."
    fi

    if [ -d "$BACKUP_DIR" ]; then
        log_info "Previous existing configuration backed up to: ${BACKUP_DIR}"
    fi
}

# ------------------------------------------------------------------------------
# Dotfiles Shell Python Virtual Environment (materialyoucolor)
# ------------------------------------------------------------------------------
setup_dotfiles_venv() {
    log_step "7/9" "Setting up Dotfiles Shell Python Virtual Environment"

    local venv="$HOME/.local/state/quickshell/.venv"
    if [ -x "$venv/bin/python" ]; then
        log_substep "Dotfiles Python venv already exists at ${venv}. Verifying dependencies..."
        "$venv/bin/python" -c "import PIL, materialyoucolor" 2>/dev/null && {
            log_success "Dotfiles Python venv dependencies are verified."
            return 0
        }
    fi

    log_substep "Creating Dotfiles Python venv at ${venv}..."
    mkdir -p "$HOME/.local/state/quickshell"
    python3 -m venv "$venv" || {
        log_warn "Failed to create Python venv for Dotfiles shell. Skipping."
        return 1
    }

    log_substep "Installing Python dependencies (pillow, materialyoucolor)..."
    "$venv/bin/pip" install --quiet --upgrade pip || true
    if ! "$venv/bin/pip" install --quiet pillow materialyoucolor; then
        log_warn "Failed to install Python dependencies into the Dotfiles venv."
        return 1
    fi

    log_success "Dotfiles Python venv ready."
}

# ------------------------------------------------------------------------------
# SDDM Greeter & Bootloader Themes Setup
# ------------------------------------------------------------------------------
configure_sddm_theme() {
    log_step "8/9" "Deploying SDDM Login Manager & Bootloader Integration"
    detect_system_hardware

    # Deploy SDDM theme (hyprland-sddm)
    local sddm_source_dir=""
    if [ -d "$DOTFILES_DIR/assets/themes/sddm/hyprland-sddm" ]; then
        sddm_source_dir="$DOTFILES_DIR/assets/themes/sddm/hyprland-sddm"
    fi

    if [ -n "$sddm_source_dir" ] && [ -f "$sddm_source_dir/install.sh" ]; then
        log_substep "Deploying Hyprland SDDM theme from $sddm_source_dir..."
        bash "$sddm_source_dir/install.sh"
    elif [ -d "/usr/share/sddm/themes/hyprland-sddm" ]; then
        log_substep "Hyprland SDDM theme is already installed at /usr/share/sddm/themes/hyprland-sddm"
    fi

    # Configure SDDM configs
    if [ -f "$DOTFILES_DIR/system/etc/sddm.conf.d/hyprland-sddm.conf" ]; then
        sudo mkdir -p /etc/sddm.conf.d
        sudo cp "$DOTFILES_DIR/system/etc/sddm.conf.d/hyprland-sddm.conf" /etc/sddm.conf.d/hyprland-sddm.conf
    fi
    if [ -f "$DOTFILES_DIR/system/etc/sddm.conf.d/theme.conf" ]; then
        sudo mkdir -p /etc/sddm.conf.d
        sudo cp "$DOTFILES_DIR/system/etc/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
    fi

    # Ensure SDDM user has access to wallpapers and fallback
    if id sddm &>/dev/null && [ -n "${HOME:-}" ]; then
        log_substep "Configuring SDDM user permissions and wallpaper ACL access..."
        sudo setfacl -m u:sddm:x "$HOME" 2>/dev/null || true
        if [ -d "$HOME/.wallpaper" ]; then
            sudo setfacl -R -m u:sddm:rX "$HOME/.wallpaper" 2>/dev/null || true
            sudo setfacl -R -d -m u:sddm:rX "$HOME/.wallpaper" 2>/dev/null || true
        fi
    fi
    sudo touch /usr/share/sddm/themes/hyprland-sddm/background.png 2>/dev/null || true
    sudo chmod 666 /usr/share/sddm/themes/hyprland-sddm/background.png 2>/dev/null || true

    # Deploy GRUB theme if GRUB is active
    if [ "$BOOTLOADER_TYPE" = "GRUB" ] && [ -d "$DOTFILES_DIR/assets/themes/grub/silent" ]; then
        log_substep "Configuring silent GRUB bootloader theme..."
        sudo mkdir -p /boot/grub/themes/silent
        sudo cp -r "$DOTFILES_DIR/assets/themes/grub/silent/"* /boot/grub/themes/silent/

        if [ -f /etc/default/grub ]; then
            # Set GRUB theme
            if ! grep -q "^GRUB_THEME=" /etc/default/grub; then
                if grep -q "^#GRUB_THEME=" /etc/default/grub; then
                    sudo sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/silent/theme.txt"|' /etc/default/grub
                else
                    echo 'GRUB_THEME="/boot/grub/themes/silent/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
                fi
            else
                sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/silent/theme.txt"|' /etc/default/grub
            fi

            # Set GRUB graphics resolution
            if ! grep -q "^GRUB_GFXMODE=" /etc/default/grub; then
                if grep -q "^#GRUB_GFXMODE=" /etc/default/grub; then
                    sudo sed -i 's|^#GRUB_GFXMODE=.*|GRUB_GFXMODE="1920x1080,auto"|' /etc/default/grub
                else
                    echo 'GRUB_GFXMODE="1920x1080,auto"' | sudo tee -a /etc/default/grub >/dev/null
                fi
            else
                sudo sed -i 's|^GRUB_GFXMODE=.*|GRUB_GFXMODE="1920x1080,auto"|' /etc/default/grub
            fi

            # Disable foreign NVRAM BootNext entries
            if ! grep -q "^GRUB_DISABLE_BOOTNEXT=" /etc/default/grub; then
                echo 'GRUB_DISABLE_BOOTNEXT="true"' | sudo tee -a /etc/default/grub >/dev/null
            fi
            if ! grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
                echo 'GRUB_DISABLE_OS_PROBER="true"' | sudo tee -a /etc/default/grub >/dev/null
            fi

            if [ -f /etc/grub.d/31_efi_bootnext ]; then
                sudo chmod -x /etc/grub.d/31_efi_bootnext 2>/dev/null || true
            fi

            log_substep "Regenerating GRUB configuration..."
            command -v grub-mkconfig >/dev/null 2>&1 && sudo grub-mkconfig -o /boot/grub/grub.cfg || true
        fi
    elif [ "$BOOTLOADER_TYPE" != "GRUB" ]; then
        log_info "Bootloader is ${BOOTLOADER_TYPE} (skipping GRUB-specific theme setup)."
    fi
}

# ------------------------------------------------------------------------------
# GSettings, Wallpaper & Live Theme Initialization
# ------------------------------------------------------------------------------
initialize_theming() {
    log_step "9/9" "Configuring GNOME/GTK Interface Settings & Material You Dynamic Colors"

    if command -v gsettings >/dev/null 2>&1; then
        log_substep "Applying Bibata-Modern-Ice cursor, WhiteSur-dark icons, and Adwaita theme..."
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    fi

    local wp_target=""
    if [ -f "$HOME/.wallpaper/Reze.png" ]; then
        wp_target="$HOME/.wallpaper/Reze.png"
    elif [ -d "$HOME/.wallpaper" ]; then
        local first_wp
        first_wp=$(find "$HOME/.wallpaper" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.webp" \) | head -n 1)
        [ -n "$first_wp" ] && wp_target="$first_wp"
    fi

    if [ -z "$wp_target" ]; then
        log_info "No wallpaper found in ~/.wallpaper. Generating default aesthetic placeholder..."
        mkdir -p "$HOME/.wallpaper"
        python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGB', (1920, 1080), color=(19, 15, 18))
draw = ImageDraw.Draw(img)
img.save('$HOME/.wallpaper/Wall.png')
" 2>/dev/null || touch "$HOME/.wallpaper/Wall.png"
        wp_target="$HOME/.wallpaper/Wall.png"
    fi

    log_substep "Running dynamic Material You theme generator on: ${wp_target}..."
    if [ -f "$HOME/.config/DotFiles/theme/apply-theme.sh" ]; then
        bash "$HOME/.config/DotFiles/theme/apply-theme.sh" "$wp_target" || true
    fi
}

# ------------------------------------------------------------------------------
# Banner & Interactive Launcher Menu
# ------------------------------------------------------------------------------
show_banner() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${CYAN}"
    echo "  ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗ "
    echo "  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗"
    echo "  ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║"
    echo "  ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║"
    echo "  ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝"
    echo "  ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ "
    echo -e "${NC}"
    echo -e "  ${BOLD}Arch Linux Universal Hyprland & Quickshell Dotfiles Suite${NC}"
    echo -e "  Universal Installer & Intelligent Hardware Driver Engine"
    echo -e "  Repository: ${BLUE}${DOTFILES_DIR}${NC}"
    echo "------------------------------------------------------------------------------"
}

show_menu() {
    show_banner
    print_hardware_report

    echo -e "${BOLD}Select an action from the Universal Launcher:${NC}"
    echo
    echo -e "  ${CYAN}[1]${NC} ${BOLD}Universal Auto-Installation${NC} ${GREEN}(Recommended)${NC}"
    echo -e "      Auto-detects drivers, installs microcode, Hyprland, Quickshell, SDDM & Themes"
    echo
    echo -e "  ${CYAN}[2]${NC} ${BOLD}Standard Desktop Installation${NC} (Core Only)"
    echo -e "      Installs auto-detected drivers and core desktop (skips optional applications)"
    echo
    echo -e "  ${CYAN}[3]${NC} ${BOLD}Full Desktop + User Applications${NC}"
    echo -e "      Core desktop plus Discord, VS Code, Telegram, Spotify, Loupe, and Media Tools"
    echo
    echo -e "  ${CYAN}[4]${NC} ${BOLD}Hardware & Driver Diagnostic Scan Only${NC} (Dry Run)"
    echo -e "      Inspect hardware, driver compatibility, and planned packages without changes"
    echo
    echo -e "  ${CYAN}[5]${NC} ${BOLD}Deploy Configuration Files & Assets Only${NC}"
    echo -e "      Quick sync of ~/.config, scripts, and themes with automated username adaptation"
    echo
    echo -e "  ${CYAN}[6]${NC} ${BOLD}Install & Configure Drivers Only${NC}"
    echo -e "      Installs auto-detected microcode, kernel headers, GPU drivers, and system quirks"
    echo
    echo -e "  ${CYAN}[7]${NC} ${BOLD}Configure 8GB Swap Space Only${NC}"
    echo
    echo -e "  ${RED}[q]${NC} Quit"
    echo
}

run_full_install() {
    check_arch_linux
    ensure_sudo
    configure_swap
    install_and_configure_drivers
    install_all_packages
    configure_system_services
    deploy_dotfiles
    setup_dotfiles_venv
    configure_sddm_theme
    initialize_theming

    echo
    echo "=============================================================================="
    log_success "Universal Dotfiles Installation Completed Successfully!"
    echo "=============================================================================="
    echo -e "  ${BOLD}Summary:${NC}"
    echo -e "  • All hardware drivers & microcode configured for your system."
    echo -e "  • User configurations dynamically adapted to: ${BLUE}${HOME}${NC}"
    echo -e "  • Add personal wallpapers anytime to: ${BLUE}~/.wallpaper/${NC}"
    echo -e "  • You can now reboot your system: ${CYAN}sudo reboot${NC}"
    echo "=============================================================================="
    echo
}

# ------------------------------------------------------------------------------
# Entrypoint & CLI Argument Handling
# ------------------------------------------------------------------------------
case "${1:-}" in
    --all|-a)
        show_banner
        INSTALL_APPS="true"
        run_full_install
        ;;
    --core|-c)
        show_banner
        INSTALL_APPS="false"
        run_full_install
        ;;
    --auto|-y|--yes)
        show_banner
        INSTALL_APPS="false"
        run_full_install
        ;;
    --scan|-s|--dry-run)
        show_banner
        print_hardware_report
        log_success "Hardware diagnostic probe completed. No system modifications were made."
        exit 0
        ;;
    --drivers-only)
        show_banner
        check_arch_linux
        ensure_sudo
        install_and_configure_drivers
        log_success "Driver installation and system configuration completed."
        exit 0
        ;;
    --config-only)
        show_banner
        check_arch_linux
        deploy_dotfiles
        setup_dotfiles_venv
        initialize_theming
        log_success "Configurations and assets deployed successfully to ${HOME}."
        exit 0
        ;;
    --swap)
        show_banner
        check_arch_linux
        ensure_sudo
        FORCE_SWAP="true" configure_swap
        exit 0
        ;;
    --help|-h)
        echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
        echo
        echo "Universal Arch Linux Hyprland & Quickshell Dotfiles Setup"
        echo
        echo "Options:"
        echo "  -y, --auto, --yes     Run universal auto-installation (unattended)"
        echo "  -c, --core            Install auto-detected drivers & core desktop (Standard)"
        echo "  -a, --all             Install auto-detected drivers, core desktop & optional applications"
        echo "  -s, --scan, --dry-run Probe hardware and print driver diagnostic report (no changes)"
        echo "      --drivers-only    Install and configure auto-detected drivers only"
        echo "      --config-only     Deploy configuration files and themes only (skip package manager)"
        echo "      --swap            Configure 8GB system swapfile (/swapfile)"
        echo "  -h, --help            Show this help manual and exit"
        echo
        echo "Run without options to launch the interactive Universal Launcher."
        exit 0
        ;;
    "")
        show_menu
        choice=""
        if [ -e /dev/tty ]; then
            read -rp "Enter selection [1-7 / q]: " choice </dev/tty || choice=""
        else
            read -rp "Enter selection [1-7 / q]: " choice || choice=""
        fi
        case "$choice" in
            1)
                INSTALL_APPS="false"
                run_full_install
                ;;
            2)
                INSTALL_APPS="false"
                run_full_install
                ;;
            3)
                INSTALL_APPS="true"
                run_full_install
                ;;
            4)
                show_banner
                print_hardware_report
                log_success "Diagnostic scan completed."
                exit 0
                ;;
            5)
                check_arch_linux
                deploy_dotfiles
                setup_dotfiles_venv
                initialize_theming
                log_success "Configurations deployed successfully!"
                ;;
            6)
                check_arch_linux
                ensure_sudo
                install_and_configure_drivers
                log_success "Driver configuration completed!"
                ;;
            7)
                check_arch_linux
                ensure_sudo
                FORCE_SWAP="true" configure_swap
                ;;
            q|Q)
                log_info "Setup aborted by user."
                exit 0
                ;;
            *)
                log_error "Invalid selection: '$choice'."
                exit 1
                ;;
        esac
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac
