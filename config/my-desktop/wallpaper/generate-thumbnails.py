#!/usr/bin/env python3
"""
Wallpaper Thumbnail Cache Generator for My-Desktop Wallpaper Picker.
Creates fast standard (240x135) and HD (720x450) thumbnails with caching based on file modification time.
"""

import os
import sys
import hashlib
from PIL import Image

WALLPAPER_DIR = os.path.expanduser(os.environ.get("WALLPAPER_DIR", "~/.wallpaper"))
CACHE_DIR = os.path.expanduser("~/.cache/my-desktop/thumbnails")
CACHE_DIR_HD = os.path.expanduser("~/.cache/my-desktop/thumbnails_hd")
SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

def get_thumb_path(file_path):
    rel_hash = hashlib.md5(file_path.encode('utf-8')).hexdigest()
    return os.path.join(CACHE_DIR, f"{rel_hash}.png")

def get_thumb_hd_path(file_path):
    rel_hash = hashlib.md5(file_path.encode('utf-8')).hexdigest()
    return os.path.join(CACHE_DIR_HD, f"{rel_hash}.jpg")

def generate_thumbnails():
    os.makedirs(CACHE_DIR, exist_ok=True)
    os.makedirs(CACHE_DIR_HD, exist_ok=True)
    
    if not os.path.isdir(WALLPAPER_DIR):
        sys.stderr.write(f"Wallpaper directory not found: {WALLPAPER_DIR}\n")
        return

    for root, _, files in os.walk(WALLPAPER_DIR):
        for f in sorted(files):
            ext = os.path.splitext(f)[1].lower()
            if ext in SUPPORTED_EXTS:
                full_path = os.path.join(root, f)
                thumb_path = get_thumb_path(full_path)
                thumb_hd_path = get_thumb_hd_path(full_path)
                
                # Check if standard thumb exists
                need_std = not (os.path.isfile(thumb_path) and os.path.getmtime(thumb_path) >= os.path.getmtime(full_path))
                need_hd = not (os.path.isfile(thumb_hd_path) and os.path.getmtime(thumb_hd_path) >= os.path.getmtime(full_path))
                
                if not need_std and not need_hd:
                    continue
                
                try:
                    with Image.open(full_path) as img:
                        img = img.convert("RGB")
                        if need_std:
                            img_std = img.copy()
                            img_std.thumbnail((240, 135), Image.Resampling.BICUBIC)
                            img_std.save(thumb_path, "PNG", optimize=True)
                        if need_hd:
                            img_hd = img.copy()
                            img_hd.thumbnail((720, 450), Image.Resampling.LANCZOS)
                            img_hd.save(thumb_hd_path, "JPEG", quality=92)
                except Exception as e:
                    sys.stderr.write(f"Failed to thumbnail {f}: {e}\n")

if __name__ == "__main__":
    generate_thumbnails()
