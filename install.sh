#!/usr/bin/env bash
# ==============================================================================
# Automated Reproducible Installer for Arch Linux + Hyprland Dotfiles
# ==============================================================================
# Hostname Blueprint: Reze
# Stack: Hyprland (Lua API), Quickshell (Modular + OSD + Plugins), Waybar fallback,
#        Material You Engine, Walker/Elephant, Dunst, Ghostty, Clipse, SDDM (qylock-sword Theme),
#        Universal Picture-in-Picture Helper, WhiteSur-dark Icons.
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
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "\n${BOLD}${CYAN}==> [STEP ${1}] ${2}${NC}"; }
log_substep() { echo -e "  ${MAGENTA}→${NC} $*"; }

# ------------------------------------------------------------------------------
# Paths & Variables
# ------------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
INSTALL_APPS="false"

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
    log_success "Verified Arch Linux environment (${NAME})."
}

ensure_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do NOT run install.sh directly as root or sudo."
        log_info "Run it as your normal user. The script will request sudo credentials when needed."
        exit 1
    fi

    log_info "Authenticating sudo credentials..."
    sudo -v || {
        log_error "Sudo authentication failed. Exiting."
        exit 1
    }

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
# Package Installation Functions
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

    log_substep "Installing ${#needed_pkgs[@]} missing AUR packages via ${AUR_HELPER}: ${needed_pkgs[*]}"
    local flags=("--needed" "--noconfirm")
    if [ "$AUR_HELPER" = "yay" ]; then
        flags+=("--answerdiff" "None" "--answerclean" "None" "--answeredit" "None" "--answerupgrade" "None")
    elif [ "$AUR_HELPER" = "paru" ]; then
        flags+=("--skipreview")
    fi

    for pkg in "${needed_pkgs[@]}"; do
        if ! pacman -T "$pkg" >/dev/null 2>&1 && ! pacman -Q "$pkg" >/dev/null 2>&1; then
            log_substep "Installing AUR package: $pkg"
            "$AUR_HELPER" -S "${flags[@]}" "$pkg" || log_warn "Failed to install AUR package '$pkg'. Skipping."
        fi
    done
}

# ------------------------------------------------------------------------------
# NVIDIA Hardware Configuration
# ------------------------------------------------------------------------------
configure_nvidia_if_present() {
    log_step "1/8" "Checking Graphics Hardware & Drivers"

    if lspci -k | grep -E -i "vga|3d|display" | grep -iq "nvidia"; then
        log_info "NVIDIA GPU hardware detected!"
        log_substep "Installing NVIDIA Open DKMS driver & VA-API utilities..."
        sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils libva-nvidia-driver dkms

        # 1. Kernel parameter in GRUB
        if [ -f /etc/default/grub ]; then
            if ! grep -q "nvidia.NVreg_PreserveVideoMemoryAllocations=1" /etc/default/grub; then
                log_substep "Configuring NVIDIA VRAM preservation parameter in /etc/default/grub..."
                sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
                if command -v grub-mkconfig >/dev/null 2>&1; then
                    log_substep "Regenerating GRUB configuration..."
                    sudo grub-mkconfig -o /boot/grub/grub.cfg || true
                fi
            else
                log_info "GRUB already configured with NVIDIA VRAM preservation."
            fi
        fi

        # 2. System services for suspend/resume
        log_substep "Enabling NVIDIA power management services (sleep/hibernate/wake)..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

        # 3. /etc/environment
        if [ -f "$DOTFILES_DIR/system/etc/environment" ]; then
            log_substep "Configuring VA-API hardware acceleration environment in /etc/environment..."
            if ! grep -q "LIBVA_DRIVER_NAME=nvidia" /etc/environment 2>/dev/null; then
                cat "$DOTFILES_DIR/system/etc/environment" | sudo tee -a /etc/environment >/dev/null
            fi
        fi
    else
        log_info "No NVIDIA GPU detected. Installing standard Mesa/Vulkan drivers..."
        sudo pacman -S --needed --noconfirm mesa vulkan-intel vulkan-radeon libva-mesa-driver 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Core Package Installation
# ------------------------------------------------------------------------------
install_all_packages() {
    log_step "2/8" "Installing Core System, Wayland & UI Packages"
    install_pacman_packages_from_file "$DOTFILES_DIR/packages/pacman-runtime.txt" "Pacman Runtime Packages"
    install_pacman_packages_from_file "$DOTFILES_DIR/packages/fonts.txt" "Font Packages"

    log_step "3/8" "Installing AUR Desktop, Theming & Launcher Packages"
    detect_or_install_aur_helper
    install_aur_packages_from_file "$DOTFILES_DIR/packages/aur-runtime.txt" "AUR Runtime Packages"

    if [ "$INSTALL_APPS" = "true" ]; then
        log_step "3b" "Installing Optional Desktop Applications & AI Agents"
        install_pacman_packages_from_file "$DOTFILES_DIR/packages/pacman-optional.txt" "Pacman Optional Apps"
        install_aur_packages_from_file "$DOTFILES_DIR/packages/aur-optional.txt" "AUR Optional Apps & Tools"
    fi
}

# ------------------------------------------------------------------------------
# System Services Configuration
# ------------------------------------------------------------------------------
configure_system_services() {
    log_step "4/8" "Enabling Required System & User Services"

    # System services
    local sys_services=("sddm.service" "NetworkManager.service" "bluetooth.service" "ntpd.service")
    for srv in "${sys_services[@]}"; do
        log_substep "Enabling system service: ${srv}"
        sudo systemctl enable "$srv" 2>/dev/null || true
    done

    # User services
    local user_services=("pipewire.service" "pipewire-pulse.service" "wireplumber.service" "elephant.service" "hypr-pip-helper.service" "quickshell.service")
    for srv in "${user_services[@]}"; do
        log_substep "Enabling user service: ${srv}"
        systemctl --user enable "$srv" 2>/dev/null || true
    done
}

# ------------------------------------------------------------------------------
# Deploy Configurations, Binaries & Assets
# ------------------------------------------------------------------------------
deploy_dotfiles() {
    log_step "5/8" "Deploying Configuration Files, Standalone Binaries & Assets"

    # 1. Create Target Directory Tree
    log_substep "Creating user directories..."
    mkdir -p "$HOME"/{.config,.local/bin,.local/lib,.wallpaper,Pictures/Screenshots,Pictures/Wallpapers}

    # 2. Deploy Configurations from config/
    log_substep "Deploying ~/.config applications..."
    local config_dirs=("hypr" "quickshell" "waybar" "dunst" "walker" "nwg-bar" "my-desktop" "ghostty" "yazi" "clipse" "gtk-3.0" "gtk-4.0" "environment.d")
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

    # Deploy bash profile if not already configured
    if [ -f "$DOTFILES_DIR/home/.bashrc" ]; then
        if [ ! -f "$HOME/.bashrc" ]; then
            cp "$DOTFILES_DIR/home/.bashrc" "$HOME/.bashrc"
        fi
    fi
    if [ -f "$DOTFILES_DIR/home/.bash_profile" ]; then
        if [ ! -f "$HOME/.bash_profile" ]; then
            cp "$DOTFILES_DIR/home/.bash_profile" "$HOME/.bash_profile"
        fi
    fi

    # 3. Deploy Standalone Binaries
    log_substep "Deploying custom binaries to ~/.local/bin/..."
    if [ -d "$DOTFILES_DIR/bin" ]; then
        cp -r "$DOTFILES_DIR/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
        chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
    fi

    # Ensure swww compatibility symlinks exist
    ln -sf "$HOME/.local/bin/awww" "$HOME/.local/bin/swww" 2>/dev/null || true
    ln -sf "$HOME/.local/bin/awww-daemon" "$HOME/.local/bin/swww-daemon" 2>/dev/null || true
    ln -sf "$HOME/.local/bin/omarchy-agent" "$HOME/.local/bin/agent" 2>/dev/null || true

    # Deploy local libraries
    if [ -d "$DOTFILES_DIR/lib" ]; then
        cp -P "$DOTFILES_DIR/lib/"* "$HOME/.local/lib/" 2>/dev/null || true
    fi

    # 4. Deploy Wallpapers, Fonts, Icons & Application Assets
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

    # 5. Set Permissions on Scripts
    log_substep "Applying executable permissions on desktop scripts..."
    chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true
    chmod +x "$HOME/.config/my-desktop/wallpaper/"*.sh "$HOME/.config/my-desktop/wallpaper/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/my-desktop/theme/"*.sh "$HOME/.config/my-desktop/theme/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/my-desktop/launcher/"*.sh "$HOME/.config/my-desktop/launcher/"*.py 2>/dev/null || true
    chmod +x "$HOME/.config/quickshell/"*.sh "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
    chmod +x "$HOME/.config/waybar/"*.sh "$HOME/.config/waybar/scripts/"*.py "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true

    if [ -d "$BACKUP_DIR" ]; then
        log_info "Previous existing configuration backed up to: ${BACKUP_DIR}"
    fi
}

# ------------------------------------------------------------------------------
# SDDM Greeter & GRUB Themes Setup
# ------------------------------------------------------------------------------
configure_sddm_theme() {
    log_step "6/8" "Deploying SDDM Login Manager & GRUB Themes"

    # Deploy SDDM theme (active: qylock-sword)
    if [ -d "$DOTFILES_DIR/assets/themes/sddm/qylock-sword" ]; then
        log_substep "Installing qylock-sword theme to /usr/share/sddm/themes/qylock-sword..."
        sudo mkdir -p /usr/share/sddm/themes/qylock-sword
        sudo cp -r "$DOTFILES_DIR/assets/themes/sddm/qylock-sword/"* /usr/share/sddm/themes/qylock-sword/
    fi

    # Deploy GRUB theme (active: silent)
    if [ -d "$DOTFILES_DIR/assets/themes/grub/silent" ]; then
        log_substep "Installing silent theme to /boot/grub/themes/silent..."
        sudo mkdir -p /boot/grub/themes/silent
        sudo cp -r "$DOTFILES_DIR/assets/themes/grub/silent/"* /boot/grub/themes/silent/
        
        if [ -f /etc/default/grub ]; then
            if ! grep -q "GRUB_THEME=" /etc/default/grub; then
                echo 'GRUB_THEME="/boot/grub/themes/silent/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
            else
                sudo sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/silent/theme.txt"|' /etc/default/grub
            fi
            command -v grub-mkconfig >/dev/null 2>&1 && sudo grub-mkconfig -o /boot/grub/grub.cfg || true
        fi
    fi

    if [ -f "$DOTFILES_DIR/system/etc/sddm.conf.d/theme.conf" ]; then
        log_substep "Configuring /etc/sddm.conf.d/theme.conf..."
        sudo mkdir -p /etc/sddm.conf.d
        sudo cp "$DOTFILES_DIR/system/etc/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
    fi
}

# ------------------------------------------------------------------------------
# GSettings, Wallpaper & Live Theme Initialization
# ------------------------------------------------------------------------------
initialize_theming() {
    log_step "7/8" "Configuring GNOME/GTK Interface Settings"

    if command -v gsettings >/dev/null 2>&1; then
        log_substep "Applying Bibata-Modern-Ice cursor, WhiteSur-dark icons, and Adwaita theme..."
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    fi

    log_step "8/8" "Initializing Dynamic Material You Palette & Wallpaper"

    local wp_target=""
    # Check if user already has wallpapers
    if [ -f "$HOME/.wallpaper/Reze.png" ]; then
        wp_target="$HOME/.wallpaper/Reze.png"
    elif [ -d "$HOME/.wallpaper" ]; then
        local first_wp
        first_wp=$(find "$HOME/.wallpaper" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.webp" \) | head -n 1)
        if [ -n "$first_wp" ]; then
            wp_target="$first_wp"
        fi
    fi

    # Fallback default image if ~/.wallpaper was empty on fresh install
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

    log_substep "Running dynamic theme generator on: ${wp_target}..."
    if [ -f "$HOME/.config/my-desktop/theme/apply-theme.sh" ]; then
        bash "$HOME/.config/my-desktop/theme/apply-theme.sh" "$wp_target" || true
    fi
}

# ------------------------------------------------------------------------------
# CLI Menu & Execution Flow
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
    echo -e "  ${BOLD}Automated Arch Linux + Hyprland Dotfiles Setup${NC}"
    echo -e "  Blueprint: ${MAGENTA}Reze (AMD Ryzen 5 + NVIDIA RTX 2050 Mobile)${NC}"
    echo -e "  Directory: ${BLUE}${DOTFILES_DIR}${NC}"
    echo "----------------------------------------------------------------------"
}

show_menu() {
    show_banner
    echo -e "${BOLD}Select an installation mode:${NC}"
    echo -e "  ${CYAN}1)${NC} ${BOLD}Standard Installation${NC} (Hyprland + Quickshell + Core Drivers & UI)"
    echo -e "  ${CYAN}2)${NC} ${BOLD}Full Desktop + User Applications${NC} (Core + Browsers, Discord, Telegram, Dev tools)"
    echo -e "  ${CYAN}3)${NC} ${BOLD}Deploy Configuration Files Only${NC} (Skip package installation)"
    echo -e "  ${CYAN}q)${NC} Quit"
    echo
}

run_install() {
    check_arch_linux
    ensure_sudo
    configure_nvidia_if_present
    install_all_packages
    configure_system_services
    deploy_dotfiles
    configure_sddm_theme
    initialize_theming

    echo
    echo "======================================================================"
    log_success "Dotfiles installation completed successfully!"
    echo "======================================================================"
    echo -e "  ${BOLD}Next steps:${NC}"
    echo -e "  1. Add your personal wallpapers to: ${BLUE}~/.wallpaper/${NC}"
    echo -e "  2. Reboot your system: ${CYAN}sudo reboot${NC}"
    echo -e "  3. Log in via SDDM and enjoy your new Hyprland environment!"
    echo "======================================================================"
    echo
}

# ------------------------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------------------------
case "${1:-}" in
    --all|-a)
        show_banner
        INSTALL_APPS="true"
        run_install
        ;;
    --core|-c)
        show_banner
        INSTALL_APPS="false"
        run_install
        ;;
    --config-only)
        show_banner
        check_arch_linux
        deploy_dotfiles
        initialize_theming
        log_success "Configurations deployed successfully!"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTION]"
        echo
        echo "Options:"
        echo "  -c, --core         Install core Hyprland desktop & shell (Standard)"
        echo "  -a, --all          Install core desktop + all optional applications"
        echo "      --config-only  Deploy config files only (skip package manager)"
        echo "  -h, --help         Show this help message"
        echo
        echo "Run without arguments for interactive selection."
        exit 0
        ;;
    "")
        show_menu
        choice=""
        if [ -e /dev/tty ]; then
            read -rp "Enter selection [1-3 / q]: " choice </dev/tty || choice=""
        else
            read -rp "Enter selection [1-3 / q]: " choice || choice=""
        fi
        case "$choice" in
            1)
                INSTALL_APPS="false"
                run_install
                ;;
            2)
                INSTALL_APPS="true"
                run_install
                ;;
            3)
                check_arch_linux
                deploy_dotfiles
                initialize_theming
                log_success "Configurations deployed successfully!"
                ;;
            q|Q)
                log_info "Installation aborted."
                exit 0
                ;;
            *)
                log_error "Invalid selection."
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
