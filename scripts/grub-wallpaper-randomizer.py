#!/usr/bin/env python3
"""
grub-wallpaper-randomizer.py
----------------------------
Randomizes or updates the background wallpaper for the GRUB theme (qylock-sword)
using wallpapers from /home/Krish/.wallpaper.

Applies subtle dark gradients and vignettes to maintain optimal contrast and
legibility for GRUB boot menu text and icons.
"""

import os
import sys
import random
import argparse
import subprocess
from PIL import Image, ImageDraw, ImageOps

WALLPAPER_DIR = "/home/Krish/.wallpaper"
GRUB_THEME_DIR = "/boot/grub/themes/qylock-sword"
DOTFILES_THEME_DIR = "/home/Krish/Dotfiles/assets/themes/grub/qylock-sword"
STATE_FILE = os.path.expanduser("~/.cache/last_grub_wallpaper")
SYSTEM_STATE_FILE = "/var/tmp/last_grub_wallpaper"
TARGET_WIDTH = 1920
TARGET_HEIGHT = 1080

SUPPORTED_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".bmp")


def get_wallpaper_list():
    if not os.path.isdir(WALLPAPER_DIR):
        return []
    wallpapers = []
    for f in os.listdir(WALLPAPER_DIR):
        if f.startswith("."):
            continue
        full_path = os.path.join(WALLPAPER_DIR, f)
        if os.path.isfile(full_path) and f.lower().endswith(SUPPORTED_EXTS):
            wallpapers.append(full_path)
    wallpapers.sort()
    return wallpapers


def get_last_wallpaper():
    for sf in (STATE_FILE, SYSTEM_STATE_FILE):
        if os.path.isfile(sf):
            try:
                with open(sf, "r", encoding="utf-8") as f:
                    return f.read().strip()
            except Exception:
                pass
    return ""


def save_last_wallpaper(path):
    for sf in (STATE_FILE, SYSTEM_STATE_FILE):
        try:
            os.makedirs(os.path.dirname(sf), exist_ok=True)
            with open(sf, "w", encoding="utf-8") as f:
                f.write(path)
        except Exception:
            pass


def pick_random_wallpaper():
    wallpapers = get_wallpaper_list()
    if not wallpapers:
        return None
    if len(wallpapers) == 1:
        return wallpapers[0]

    last_wp = get_last_wallpaper()
    candidates = [w for w in wallpapers if w != last_wp]
    if not candidates:
        candidates = wallpapers
    return random.choice(candidates)


def process_image(src_path, dest_path, width=TARGET_WIDTH, height=TARGET_HEIGHT):
    img = Image.open(src_path)
    img = ImageOps.exif_transpose(img).convert("RGBA")

    # Cover-fit / center-crop
    iw, ih = img.size
    scale = max(width / iw, height / ih)
    nw, nh = int(round(iw * scale)), int(round(ih * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)

    left = (nw - width) // 2
    top = (nh - height) // 2
    img = img.crop((left, top, left + width, top + height))

    # Top and bottom dark gradient for crisp text overlay
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Bottom gradient (protects timeout & footer text)
    for y in range(height):
        if y > 550:
            alpha = int(((y - 550) / (height - 550)) ** 1.4 * 190)
            draw.line([(0, y), (width, y)], fill=(5, 8, 16, alpha))
        elif y < 220:
            alpha = int(((220 - y) / 220.0) ** 1.5 * 140)
            draw.line([(0, y), (width, y)], fill=(5, 8, 16, alpha))

    # Radial vignette (darkens screen edges)
    vignette = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    for r in range(450, 1250, 10):
        alpha = int(((r - 450) / 800.0) ** 2 * 130)
        v_draw.ellipse(
            [(width // 2 - r, height // 2 - r), (width // 2 + r, height // 2 + r)],
            outline=(5, 8, 16, alpha),
            width=10,
        )

    final = Image.alpha_composite(img, overlay)
    final = Image.alpha_composite(final, vignette)

    # Save to temp file first
    tmp_dest = dest_path + ".tmp.png"
    try:
        final.save(tmp_dest, "PNG", optimize=False)
        os.replace(tmp_dest, dest_path)
        return True
    except PermissionError:
        # Fallback to saving to /tmp and using non-interactive sudo copy if non-root
        fallback_tmp = "/tmp/grub_random_bg.png"
        final.save(fallback_tmp, "PNG", optimize=False)
        res = subprocess.run(["sudo", "-n", "cp", fallback_tmp, dest_path], capture_output=True)
        if res.returncode == 0:
            return True
        return False
    except Exception as e:
        print(f"Error saving processed image: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="GRUB Theme Wallpaper Randomizer")
    parser.add_argument("--wallpaper", "-w", help="Specific wallpaper path to set")
    parser.add_argument("--sync-current", action="store_true", help="Use currently active desktop wallpaper")
    parser.add_argument("--quiet", "-q", action="store_true", help="Quiet mode (no console output)")
    args = parser.parse_args()

    selected_wp = None
    if args.wallpaper:
        if os.path.isfile(args.wallpaper):
            selected_wp = os.path.abspath(args.wallpaper)
        else:
            print(f"Error: Specified wallpaper not found: {args.wallpaper}", file=sys.stderr)
            sys.exit(1)
    elif args.sync_current:
        current_file = os.path.expanduser("~/.config/my-desktop/wallpaper/current")
        if os.path.isfile(current_file):
            try:
                with open(current_file, "r", encoding="utf-8") as f:
                    candidate = f.read().strip()
                if os.path.isfile(candidate):
                    selected_wp = candidate
            except Exception:
                pass

    if not selected_wp:
        selected_wp = pick_random_wallpaper()

    if not selected_wp or not os.path.isfile(selected_wp):
        if not args.quiet:
            print("No wallpapers found in", WALLPAPER_DIR, file=sys.stderr)
        sys.exit(1)

    # Destination paths
    boot_target = os.path.join(GRUB_THEME_DIR, "background.png")
    dotfiles_target = os.path.join(DOTFILES_THEME_DIR, "background.png")

    # 1. Render directly to Dotfiles if writable
    if os.path.isdir(DOTFILES_THEME_DIR):
        try:
            process_image(selected_wp, dotfiles_target)
        except Exception:
            pass

    # 2. Render to /boot/grub/themes/qylock-sword/background.png
    if os.path.isdir(GRUB_THEME_DIR):
        success = process_image(selected_wp, boot_target)
        if not success:
            if not args.quiet:
                print(f"Warning: Could not write directly to {boot_target}", file=sys.stderr)
    else:
        if not args.quiet:
            print(f"GRUB theme directory not found at {GRUB_THEME_DIR}", file=sys.stderr)

    save_last_wallpaper(selected_wp)

    if not args.quiet:
        print(f"✓ GRUB theme background updated to: {os.path.basename(selected_wp)}")


if __name__ == "__main__":
    main()
