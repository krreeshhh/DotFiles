#!/usr/bin/env bash
# ==============================================================================
# Standalone Basic Hyprland Setup & Core Wayland Environment
# Location: scripts/hyprland.sh
# ==============================================================================
# Installs the essential Hyprland compositor, Wayland portals, core audio/bluetooth
# stack, SDDM display manager, and foundational utilities.
# Can be executed standalone or invoked automatically by install.sh.
# ==============================================================================

set -euo pipefail

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
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "\n${BOLD}${CYAN}==> [STEP ${1}] ${2}${NC}"; }
log_substep() { echo -e "  ${MAGENTA}->${NC} $*"; }

# ------------------------------------------------------------------------------
# Default Options
# ------------------------------------------------------------------------------
NON_INTERACTIVE="false"
REFRESH_MIRRORS="false"

# ------------------------------------------------------------------------------
# CLI Arguments Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        -m|--refresh-mirrors)
            REFRESH_MIRRORS="true"
            shift
            ;;
        -h|--help)
            echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  -y, --non-interactive   Run without interactive prompts"
            echo "  -m, --refresh-mirrors   Optimize pacman mirrorlist via reflector (India)"
            echo "  -h, --help              Display this help message and exit"
            echo
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

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
        log_error "This script is built exclusively for Arch Linux (detected: ${NAME:-Unknown})."
        exit 1
    fi
    log_success "Verified Arch Linux environment (${NAME})."
}

ensure_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run hyprland.sh directly as root or sudo."
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
# Mirror Configuration (Optional)
# ------------------------------------------------------------------------------
configure_mirrors() {
    if [ "$NON_INTERACTIVE" = "false" ] && [ "$REFRESH_MIRRORS" = "false" ]; then
        echo
        read -rp "Would you like to optimize pacman mirrors using reflector? (y/N): " mirror_choice || mirror_choice="n"
        if [[ "$mirror_choice" =~ ^[Yy]$ ]]; then
            REFRESH_MIRRORS="true"
        fi
    fi

    if [ "$REFRESH_MIRRORS" = "true" ]; then
        log_step "1/4" "Configuring Pacman Mirrors via Reflector"
        log_substep "Ensuring reflector is installed..."
        sudo pacman -S --needed --noconfirm reflector
        log_substep "Finding top 5 fastest mirrors for India..."
        sudo reflector --country India --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
        log_substep "Refreshing pacman database..."
        sudo pacman -Syy
        log_success "Pacman mirrorlist updated successfully."
    else
        log_info "Skipping mirror optimization."
    fi
}

# ------------------------------------------------------------------------------
# Core Package Installation
# ------------------------------------------------------------------------------
install_base_packages() {
    log_step "2/4" "Installing Base Hyprland & Wayland Stack"

    local base_packages=(
        # Compositor & Portals
        hyprland
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        polkit-gnome

        # Core Window Manager Utilities & Controls
        waybar
        dunst
        swaybg
        wl-clipboard
        grim
        slurp
        brightnessctl
        pamixer
        pavucontrol
        file-roller
        xdg-user-dirs

        # Audio Server & Routing
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber

        # Network & Bluetooth Management
        networkmanager
        network-manager-applet
        bluez
        bluez-utils
        blueman

        # Display Manager
        sddm

        # Foundational Fonts
        ttf-jetbrains-mono-nerd
        noto-fonts
        noto-fonts-emoji
    )

    log_substep "Checking and installing ${#base_packages[@]} base packages via pacman..."
    sudo pacman -S --needed --noconfirm "${base_packages[@]}"
    log_success "All base Hyprland packages installed successfully."
}

# ------------------------------------------------------------------------------
# Service Enablement
# ------------------------------------------------------------------------------
configure_services() {
    log_step "3/4" "Enabling Core System & User Daemons"

    # System services
    local system_services=(
        "NetworkManager.service"
        "bluetooth.service"
        "sddm.service"
    )

    for srv in "${system_services[@]}"; do
        log_substep "Enabling system service: ${srv}"
        sudo systemctl enable "$srv" 2>/dev/null || true
    done

    # User audio services
    local user_services=(
        "pipewire.service"
        "pipewire-pulse.service"
        "wireplumber.service"
    )

    for srv in "${user_services[@]}"; do
        log_substep "Enabling user service: ${srv}"
        systemctl --user enable "$srv" 2>/dev/null || true
    done

    # Initialize standard user directories (~/Downloads, ~/Pictures, etc.)
    if command -v xdg-user-dirs-update >/dev/null 2>&1; then
        log_substep "Updating XDG user directories..."
        xdg-user-dirs-update 2>/dev/null || true
    fi

    log_success "Base services enabled."
}

# ------------------------------------------------------------------------------
# Summary & Completion
# ------------------------------------------------------------------------------
finish_setup() {
    log_step "4/4" "Basic Hyprland Setup Complete"
    echo
    log_success "Base Hyprland environment is ready!"
    log_info "To install the full dotfiles suite (Quickshell, Material You theme engine),"
    log_info "run: ./install.sh"
    echo
}

# ------------------------------------------------------------------------------
# Main Flow
# ------------------------------------------------------------------------------
check_arch_linux
ensure_sudo
configure_mirrors
install_base_packages
configure_services
finish_setup
