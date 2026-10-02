#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Repository Integrity & Automated Test Suite
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -c "
import os, sys, glob, subprocess, py_compile

passed = 0
failed = 0
total = 0

def test(name, condition, details=''):
    global passed, failed, total
    total += 1
    if condition:
        passed += 1
        print(f'  \033[92m✔\033[0m {name}')
    else:
        failed += 1
        print(f'  \033[91m✖\033[0m {name} - \033[33m{details}\033[0m')

DOTFILES = '$DOTFILES_DIR'

print('\n\033[1;36m======================================================================\033[0m')
print('        \033[1mARCH LINUX + HYPRLAND DOTFILES VERIFICATION SUITE\033[0m')
print('\033[1;36m======================================================================\033[0m\n')

# 1. Structure & Core Manifests
print('\033[1m[1. Directory Structure & Core Manifests]\033[0m')
test('Dotfiles repository path exists', os.path.isdir(DOTFILES))
test('install.sh exists & is executable', os.path.isfile(f'{DOTFILES}/install.sh') and os.access(f'{DOTFILES}/install.sh', os.X_OK))
test('scripts/hyprland.sh exists & is executable', os.path.isfile(f'{DOTFILES}/scripts/hyprland.sh') and os.access(f'{DOTFILES}/scripts/hyprland.sh', os.X_OK))
test('MANIFEST.md documentation present', os.path.isfile(f'{DOTFILES}/MANIFEST.md'))
test('REPRODUCTION.md reproduction guide present', os.path.isfile(f'{DOTFILES}/REPRODUCTION.md'))
test('INSTALL-ORDER.md deployment checklist present', os.path.isfile(f'{DOTFILES}/INSTALL-ORDER.md'))

# 2. Package Manifests & Clean State
print('\n\033[1m[2. Package Manifests & Accuracy]\033[0m')
pkg_dir = f'{DOTFILES}/packages'
test('packages/pacman-runtime.txt present', os.path.isfile(f'{pkg_dir}/pacman-runtime.txt'))
test('packages/aur-runtime.txt present', os.path.isfile(f'{pkg_dir}/aur-runtime.txt'))
test('packages/pacman-optional.txt present', os.path.isfile(f'{pkg_dir}/pacman-optional.txt'))
test('packages/aur-optional.txt present', os.path.isfile(f'{pkg_dir}/aur-optional.txt'))
test('packages/fonts.txt present', os.path.isfile(f'{pkg_dir}/fonts.txt'))
test('packages/manual-install.txt present', os.path.isfile(f'{pkg_dir}/manual-install.txt'))

with open(f'{pkg_dir}/pacman-runtime.txt') as f:
    pac_runtime = f.read().splitlines()
with open(f'{pkg_dir}/aur-runtime.txt') as f:
    aur_runtime = f.read().splitlines()
with open(f'{pkg_dir}/aur-optional.txt') as f:
    aur_optional = f.read().splitlines()

test('nautilus present in pacman-runtime.txt', 'nautilus' in pac_runtime)
test('dolphin NOT present in pacman-runtime.txt', 'dolphin' not in pac_runtime)
test('brave-origin-bin present in aur-optional.txt', 'brave-origin-bin' in aur_optional)
test('helium-browser-bin NOT present in package manifests', 'helium-browser-bin' not in aur_runtime and 'helium-browser-bin' not in aur_optional)
test('whitesur-icon-theme present in aur-runtime.txt', 'whitesur-icon-theme' in aur_runtime)
test('bibata-cursor-theme present in aur-runtime.txt', 'bibata-cursor-theme' in aur_runtime)
test('walker-bin & elephant-bin present in aur-runtime.txt', 'walker-bin' in aur_runtime and 'elephant-bin' in aur_runtime)
test('herdr-bin present in aur-runtime.txt', 'herdr-bin' in aur_runtime)
test('udisks2 & udiskie present in pacman-runtime.txt', 'udisks2' in pac_runtime and 'udiskie' in pac_runtime)
test('gvfs & mobile MTP/AFC plugins present in pacman-runtime.txt', 'gvfs' in pac_runtime and 'gvfs-mtp' in pac_runtime and 'gvfs-afc' in pac_runtime)
test('USB filesystem drivers (dosfstools, exfatprogs, ntfs-3g) present', 'dosfstools' in pac_runtime and 'exfatprogs' in pac_runtime and 'ntfs-3g' in pac_runtime)
test('mobile USB udev & daemons (android-udev, usbmuxd, libimobiledevice) present', 'android-udev' in pac_runtime and 'usbmuxd' in pac_runtime and 'libimobiledevice' in pac_runtime)
test('hypridle present in pacman-runtime.txt', 'hypridle' in pac_runtime)

# 3. Hyprland Configuration
print('\n\033[1m[3. Hyprland Configuration & Helper Daemons]\033[0m')
hypr_dir = f'{DOTFILES}/config/hypr'
test('hyprland.lua present', os.path.isfile(f'{hypr_dir}/hyprland.lua'))
test('hyprland.conf present', os.path.isfile(f'{hypr_dir}/hyprland.conf'))
test('hypridle.conf present', os.path.isfile(f'{hypr_dir}/hypridle.conf'))
test('pip.lua (Universal PiP helper config) present', os.path.isfile(f'{hypr_dir}/pip.lua'))
test('scripts/autostart.py present', os.path.isfile(f'{hypr_dir}/scripts/autostart.py'))
test('scripts/battery-alert.sh present and executable', os.path.isfile(f'{hypr_dir}/scripts/battery-alert.sh') and os.access(f'{hypr_dir}/scripts/battery-alert.sh', os.X_OK))
test('scripts/brightness.sh present and executable', os.path.isfile(f'{hypr_dir}/scripts/brightness.sh') and os.access(f'{hypr_dir}/scripts/brightness.sh', os.X_OK))
test('scripts/volume.sh present and executable', os.path.isfile(f'{hypr_dir}/scripts/volume.sh') and os.access(f'{hypr_dir}/scripts/volume.sh', os.X_OK))
test('scripts/screenshot.sh present and executable', os.path.isfile(f'{hypr_dir}/scripts/screenshot.sh') and os.access(f'{hypr_dir}/scripts/screenshot.sh', os.X_OK))
test('scripts/caffeine.sh present and executable', os.path.isfile(f'{hypr_dir}/scripts/caffeine.sh') and os.access(f'{hypr_dir}/scripts/caffeine.sh', os.X_OK))
test('udiskie USB automount configured in hyprland.lua & hyprland.conf', 'udiskie' in open(f'{hypr_dir}/hyprland.lua').read() and 'udiskie' in open(f'{hypr_dir}/hyprland.conf').read())
test('hypridle autostart configured in hyprland.lua & hyprland.conf', 'hypridle' in open(f'{hypr_dir}/hyprland.lua').read() and 'hypridle' in open(f'{hypr_dir}/hyprland.conf').read())

# 4. Quickshell Desktop Shell
print('\n\033[1m[4. Quickshell Components, OSD & Plugins]\033[0m')
qs_dir = f'{DOTFILES}/config/quickshell'
test('shell.qml present', os.path.isfile(f'{qs_dir}/shell.qml'))
test('Theme.qml present', os.path.isfile(f'{qs_dir}/Theme.qml'))
test('bar/Bar.qml present', os.path.isfile(f'{qs_dir}/bar/Bar.qml'))
test('bar/Workspaces.qml present', os.path.isfile(f'{qs_dir}/bar/Workspaces.qml'))
test('bar/StatusCluster.qml present', os.path.isfile(f'{qs_dir}/bar/StatusCluster.qml'))
test('popups/ControlCenter.qml present', os.path.isfile(f'{qs_dir}/popups/ControlCenter.qml'))
test('popups/Osd.qml present', os.path.isfile(f'{qs_dir}/popups/Osd.qml'))
test('popups/AuthDialog.qml present', os.path.isfile(f'{qs_dir}/popups/AuthDialog.qml'))
test('popups/PromptDialog.qml present', os.path.isfile(f'{qs_dir}/popups/PromptDialog.qml'))
test('plugins/omarchy-ledge plugin tree present', os.path.isdir(f'{qs_dir}/plugins/omarchy-ledge'))
test('launch.sh & switch.sh present and executable', os.access(f'{qs_dir}/launch.sh', os.X_OK) and os.access(f'{qs_dir}/switch.sh', os.X_OK))

# 5. My-Desktop Wallpaper & Material You Theming
print('\n\033[1m[5. Wallpaper Engine, Theme Extractor & Launcher]\033[0m')
md_dir = f'{DOTFILES}/config/my-desktop'
test('carousel-picker.py present and executable', os.path.isfile(f'{md_dir}/wallpaper/carousel-picker.py') and os.access(f'{md_dir}/wallpaper/carousel-picker.py', os.X_OK))
test('apply-wallpaper.sh present and executable', os.path.isfile(f'{md_dir}/wallpaper/apply-wallpaper.sh') and os.access(f'{md_dir}/wallpaper/apply-wallpaper.sh', os.X_OK))
test('generate-thumbnails.py present and executable', os.path.isfile(f'{md_dir}/wallpaper/generate-thumbnails.py') and os.access(f'{md_dir}/wallpaper/generate-thumbnails.py', os.X_OK))
test('generate-theme.py present and executable', os.path.isfile(f'{md_dir}/theme/generate-theme.py') and os.access(f'{md_dir}/theme/generate-theme.py', os.X_OK))
test('apply-theme.sh present and executable', os.path.isfile(f'{md_dir}/theme/apply-theme.sh') and os.access(f'{md_dir}/theme/apply-theme.sh', os.X_OK))
test('launcher.sh present and executable', os.path.isfile(f'{md_dir}/launcher/launcher.sh') and os.access(f'{md_dir}/launcher/launcher.sh', os.X_OK))

# 6. Look, Feel & Terminals
print('\n\033[1m[6. Look, Feel & Terminal Configurations]\033[0m')
test('dunst/dunstrc present', os.path.isfile(f'{DOTFILES}/config/dunst/dunstrc'))
test('ghostty/config present', os.path.isfile(f'{DOTFILES}/config/ghostty/config'))
test('gtk-3.0/settings.ini present', os.path.isfile(f'{DOTFILES}/config/gtk-3.0/settings.ini'))
test('gtk-4.0/settings.ini present', os.path.isfile(f'{DOTFILES}/config/gtk-4.0/settings.ini'))
test('environment.d configs present', os.path.isfile(f'{DOTFILES}/config/environment.d/theme.conf') and os.path.isfile(f'{DOTFILES}/config/environment.d/quickshell.conf'))
test('clipse/config.json present', os.path.isfile(f'{DOTFILES}/config/clipse/config.json'))
test('yazi/theme.toml present', os.path.isfile(f'{DOTFILES}/config/yazi/theme.toml'))
test('herdr/config.toml present', os.path.isfile(f'{DOTFILES}/config/herdr/config.toml'))
test('mimeapps.list present', os.path.isfile(f'{DOTFILES}/config/mimeapps.list'))

# 7. Standalone Binaries & Systemd Units
print('\n\033[1m[7. Standalone Binaries & Systemd Services]\033[0m')
bin_dir = f'{DOTFILES}/bin'
test('bin/hypr-pip-helper present and executable', os.path.isfile(f'{bin_dir}/hypr-pip-helper') and os.access(f'{bin_dir}/hypr-pip-helper', os.X_OK))
test('bin/clipse present and executable', os.path.isfile(f'{bin_dir}/clipse') and os.access(f'{bin_dir}/clipse', os.X_OK))
test('bin/omarchy present and executable', os.path.isfile(f'{bin_dir}/omarchy') and os.access(f'{bin_dir}/omarchy', os.X_OK))
test('bin/strata present and executable', os.path.isfile(f'{bin_dir}/strata') and os.access(f'{bin_dir}/strata', os.X_OK))

sd_dir = f'{DOTFILES}/config/systemd/user'
test('systemd hypr-pip-helper.service present', os.path.isfile(f'{sd_dir}/hypr-pip-helper.service'))
test('systemd quickshell.service present', os.path.isfile(f'{sd_dir}/quickshell.service'))
test('systemd elephant.service present', os.path.isfile(f'{sd_dir}/elephant.service'))
test('systemd battery-alert.service present', os.path.isfile(f'{sd_dir}/battery-alert.service'))
test('systemd omarchy-crash-watch.service present', os.path.isfile(f'{sd_dir}/omarchy-crash-watch.service'))

# 8. Script Syntax Compilation Checks
print('\n\033[1m[8. Script Syntax Compilation Checks]\033[0m')
sh_files = glob.glob(f'{DOTFILES}/**/*.sh', recursive=True)
all_sh_ok = True
for sh in sh_files:
    res = subprocess.run(['bash', '-n', sh], capture_output=True, text=True)
    if res.returncode != 0:
        all_sh_ok = False
        print(f'Bash syntax error in {sh}: {res.stderr}')
test(f'All {len(sh_files)} shell scripts passed bash -n check', all_sh_ok)

py_files = glob.glob(f'{DOTFILES}/**/*.py', recursive=True)
all_py_ok = True
for py in py_files:
    try:
        py_compile.compile(py, doraise=True)
    except Exception as e:
        all_py_ok = False
        print(f'Python compile error in {py}: {e}')
test(f'All {len(py_files)} python scripts compiled cleanly', all_py_ok)

# 9. Asset Repositories & Wallpapers
print('\n\033[1m[9. Wallpapers, Fonts, Desktop Shortcuts & Active Themes]\033[0m')
test('assets/wallpapers/ directory present with >20 wallpapers', os.path.isdir(f'{DOTFILES}/assets/wallpapers') and len(glob.glob(f'{DOTFILES}/assets/wallpapers/*.png')) >= 20)
test('assets/fonts/ custom fonts present (The Last Shuriken & Torus)', os.path.isfile(f'{DOTFILES}/assets/fonts/qylock-sword/The Last Shuriken.ttf') and os.path.isfile(f'{DOTFILES}/assets/fonts/osu/Torus Regular.otf'))
test('assets/share/icons/webapps/ present', os.path.isfile(f'{DOTFILES}/assets/share/icons/webapps/whatsapp.png'))
test('assets/share/applications/ custom desktop entries present', os.path.isfile(f'{DOTFILES}/assets/share/applications/webapp-whatsapp.desktop'))
test('active SDDM theme (hyprland-sddm) present', os.path.isfile('/home/Krish/hyprland-sddm/Main.qml') or os.path.isfile('/usr/share/sddm/themes/hyprland-sddm/Main.qml'))
test('legacy SDDM themes (qylock-sword, R1999_1) NOT present in dotfiles', not os.path.exists(f'{DOTFILES}/assets/themes/sddm'))
test('active GRUB theme (silent) present', os.path.isfile(f'{DOTFILES}/assets/themes/grub/silent/theme.txt'))
test('unused GRUB theme (qylock-sword) NOT present in dotfiles', not os.path.exists(f'{DOTFILES}/assets/themes/grub/qylock-sword'))
test('rofi NOT in pacman-runtime.txt (Quickshell is active launcher)', 'rofi' not in pac_runtime)

# 10. Installer CLI & Integration Test
print('\n\033[1m[10. Installer CLI Interface Checks]\033[0m')
res_help = subprocess.run([f'{DOTFILES}/install.sh', '--help'], capture_output=True, text=True)
test('install.sh --help flag works and outputs help menu', res_help.returncode == 0 and 'Usage:' in res_help.stdout)

# 11. Antigravity Agent, Mechanic Skill & Sudo Password Screen
print('\n\033[1m[11. Antigravity Agent, Mechanic Skill & Sudo Password Screen]\033[0m')
agent_dir = f'{DOTFILES}/home/.agents'
test('home/.agents/skills/mechanic/SKILL.md present', os.path.isfile(f'{agent_dir}/skills/mechanic/SKILL.md'))
test('home/.agents/rules/mechanic.md present', os.path.isfile(f'{agent_dir}/rules/mechanic.md'))
test('home/.agents/skills/diagnose-crash/SKILL.md present', os.path.isfile(f'{agent_dir}/skills/diagnose-crash/SKILL.md'))
test('home/.agents/skills/quickshell-dev/SKILL.md present', os.path.isfile(f'{agent_dir}/skills/quickshell-dev/SKILL.md'))
test('home/.agents/skills/hyprland-config/SKILL.md present', os.path.isfile(f'{agent_dir}/skills/hyprland-config/SKILL.md'))
test('home/.agents/skills/theme-manager/SKILL.md present', os.path.isfile(f'{agent_dir}/skills/theme-manager/SKILL.md'))
test('bin/mechanic-askpass present and executable', os.path.isfile(f'{bin_dir}/mechanic-askpass') and os.access(f'{bin_dir}/mechanic-askpass', os.X_OK))
test('bin/mechanic present and executable', os.path.isfile(f'{bin_dir}/mechanic') and os.access(f'{bin_dir}/mechanic', os.X_OK))
test('Quickshell native sudo AuthDialog.qml present', os.path.isfile(f'{qs_dir}/popups/AuthDialog.qml'))
with open(f'{DOTFILES}/home/.bashrc') as f:
    bashrc_content = f.read()
test('home/.bashrc configures SUDO_ASKPASS and DEFAULT_AGENT', 'SUDO_ASKPASS' in bashrc_content and 'DEFAULT_AGENT' in bashrc_content)

# 12. Formatting Integrity Check
print('\n\033[1m[12. Formatting & Compliance Checks]\033[0m')
em_dash_char = chr(8212)
tracked_files = glob.glob(f'{DOTFILES}/**/*', recursive=True)
em_dash_clean = True
for fpath in tracked_files:
    if os.path.isfile(fpath) and not fpath.endswith(('.png', '.jpg', '.jpeg', '.webp', '.mp4', '.webm', '.otf', '.ttf', '.pf2', '.zip', '.tar.zst', '.git', '.so', '.so.0', '.so.1', '.so.2', '.a')):
        try:
            with open(fpath, 'rb') as bf:
                if bf.read(4) == b'\x7fELF':
                    continue
            with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                if em_dash_char in f.read():
                    em_dash_clean = False
                    print(f'Em dash found in: {fpath}')
        except Exception:
            pass
test('Strictly zero em dashes in source and configs', em_dash_clean)

print('\n\033[1;36m======================================================================\033[0m')
print(f' \033[1mTEST RESULTS: {passed}/{total} checks passed ({failed} failures)\033[0m')
print('\033[1;36m======================================================================\033[0m\n')

if failed > 0:
    sys.exit(1)
"
