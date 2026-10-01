#!/usr/bin/env bash
# ==============================================================================
# Arch Linux Application & AI Agent Installer (via AUR / Pacman)
# Location: ~/Scripts/install_apps.sh
# ==============================================================================

set -uo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# Check / Select AUR Helper
detect_aur_helper() {
    if command -v yay &>/dev/null; then
        echo "yay"
    elif command -v paru &>/dev/null; then
        echo "paru"
    else
        echo ""
    fi
}

# Ensure AUR helper is available
AUR_HELPER=$(detect_aur_helper)
if [[ -z "$AUR_HELPER" ]]; then
    log_error "No AUR helper (yay or paru) found on your system."
    log_info "To install yay, run:"
    echo "  sudo pacman -S --needed base-devel git"
    echo "  git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si"
    exit 1
fi

log_info "Using AUR helper: ${BOLD}${AUR_HELPER}${NC}"

# Authenticate sudo once upfront and keep it alive in the background
ensure_sudo() {
    log_info "Authenticating sudo credentials..."
    sudo -v || {
        log_error "Sudo authentication failed. Exiting."
        exit 1
    }
    # Keep sudo timestamp alive during the entire script run
    (while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill -9 "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

# ------------------------------------------------------------------------------
# Package Definitions
# ------------------------------------------------------------------------------

# GUI & Desktop Applications
APPS=(
    "ab-download-manager-bin"   # AB Download Manager
    "cliamp-bin"                # cliamp (Retro terminal music player)
    "ghostty"                   # Ghostty Terminal Emulator (Repo/AUR)
    "helium-browser-bin"        # Helium Web Browser
    "localsend-bin"             # LocalSend (AirDrop alternative)
    "fagram-bin"                # FAgram (Feature-rich Telegram client)
    "cine"                      # Cine (Linux Video Player)
    "neovim"                    # Neovim Editor
    "obsidian"                  # Obsidian Note Taking
    "sonora-bin"                # Sonora (Native Music Streaming client)
    "upscayl-bin"               # Upscayl (AI Image Upscaler)
    "vesktop-bin"               # Vesktop (Vencord + Discord client)
)

# System Packages & Terminal Tools
SYSTEM_PACKAGES=(
    "tmux"                      # Terminal Multiplexer
    "herdr-bin"                 # Herdr (AI Coding Agent supervisor/workspace manager)
)

# AI Coding Agents & Platforms
AI_AGENTS=(
    "claude-code"               # Anthropic Claude Code CLI
    "openai-codex-bin"          # OpenAI Codex CLI
    "antigravity-cli"           # Google Antigravity CLI
    "opencode"                  # OpenCode AI coding agent
    "kiro-cli"                  # Kiro Code CLI
    "cline-cli"                 # Cline Autonomous Coding Agent CLI
    "hermes-agent-bin"          # Hermes Agent (Nous Research locally-run AI agent)
)

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

is_installed() {
    pacman -Qq "$1" &>/dev/null
}

install_package_list() {
    local category_name="$1"
    shift
    local packages=("$@")

    log_section "Installing: ${category_name}"

    local to_install=()
    for pkg in "${packages[@]}"; do
        if is_installed "$pkg"; then
            log_info "  [Already Installed] ${pkg}"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_success "All packages in '${category_name}' are already installed."
        return 0
    fi

    log_info "Packages to install: ${to_install[*]}"
    
    # Flags for completely unattended installation (no questions asked)
    local helper_flags=("--needed" "--noconfirm")

    if [[ "$AUR_HELPER" == "yay" ]]; then
        helper_flags+=("--answerdiff" "None" "--answerclean" "None" "--answeredit" "None" "--answerupgrade" "None")
    elif [[ "$AUR_HELPER" == "paru" ]]; then
        helper_flags+=("--skipreview")
    fi

    # Run AUR helper installation
    if "$AUR_HELPER" -S "${helper_flags[@]}" "${to_install[@]}"; then
        log_success "Successfully installed '${category_name}'."
    else
        log_warn "Some packages in '${category_name}' failed to install."
    fi
}

show_menu() {
    echo -e "${BOLD}Select an installation option:${NC}"
    echo "  1) Install All (Apps, System Packages, AI Agents)"
    echo "  2) Install Desktop Apps only"
    echo "  3) Install System Packages only (Tmux, Herdr)"
    echo "  4) Install AI Agents only (Claude Code, Codex, Antigravity, OpenCode, Kiro, Cline, Hermes)"
    echo "  q) Quit"
    echo
}

# ------------------------------------------------------------------------------
# Main Logic
# ------------------------------------------------------------------------------

main() {
    case "${1:-}" in
        --all|-a)
            ensure_sudo
            install_package_list "Applications" "${APPS[@]}"
            install_package_list "System Packages" "${SYSTEM_PACKAGES[@]}"
            install_package_list "AI Agents" "${AI_AGENTS[@]}"
            ;;
        --apps)
            ensure_sudo
            install_package_list "Applications" "${APPS[@]}"
            ;;
        --packages)
            ensure_sudo
            install_package_list "System Packages" "${SYSTEM_PACKAGES[@]}"
            ;;
        --agents)
            ensure_sudo
            install_package_list "AI Agents" "${AI_AGENTS[@]}"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTION]"
            echo
            echo "Options:"
            echo "  -a, --all        Install all categories without prompts"
            echo "      --apps       Install desktop applications"
            echo "      --packages   Install system tools (Tmux, Herdr)"
            echo "      --agents     Install AI coding agents"
            echo "  -h, --help       Show this help message"
            echo
            echo "Run without arguments for interactive selection."
            exit 0
            ;;
        "")
            show_menu
            read -rp "Enter choice [1-4 / q]: " choice
            case "$choice" in
                1)
                    ensure_sudo
                    install_package_list "Applications" "${APPS[@]}"
                    install_package_list "System Packages" "${SYSTEM_PACKAGES[@]}"
                    install_package_list "AI Agents" "${AI_AGENTS[@]}"
                    ;;
                2)
                    ensure_sudo
                    install_package_list "Applications" "${APPS[@]}"
                    ;;
                3)
                    ensure_sudo
                    install_package_list "System Packages" "${SYSTEM_PACKAGES[@]}"
                    ;;
                4)
                    ensure_sudo
                    install_package_list "AI Agents" "${AI_AGENTS[@]}"
                    ;;
                q|Q)
                    log_info "Exiting."
                    exit 0
                    ;;
                *)
                    log_error "Invalid selection: $choice"
                    exit 1
                    ;;
            esac
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use '$0 --help' for usage."
            exit 1
            ;;
    esac

    log_section "Installation Completed"
}

main "$@"
