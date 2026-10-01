#!/usr/bin/env python3
"""
Asset Generator for SilentGRUB Theme
Generates crisp 9-slice / 3-slice pixmaps, backgrounds, and icons.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFilter

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PIXMAPS_DIR = os.path.join(BASE_DIR, "pixmaps")
ICONS_DIR = os.path.join(BASE_DIR, "icons")
FONTS_DIR = os.path.join(BASE_DIR, "fonts")
os.makedirs(PIXMAPS_DIR, exist_ok=True)
os.makedirs(ICONS_DIR, exist_ok=True)
os.makedirs(FONTS_DIR, exist_ok=True)

def create_9slice(name, size, radius, fill_color, border_color=None, border_width=1):
    """
    Creates a 9-slice pixmap set (nw, n, ne, w, c, e, sw, s, se).
    """
    w, h = size
    # Draw high-res and downsample for smooth anti-aliased corners
    scale = 4
    sw, sh = w * scale, h * scale
    s_radius = radius * scale
    s_bw = border_width * scale

    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if border_color and border_width > 0:
        draw.rounded_rectangle(
            [(s_bw // 2, s_bw // 2), (sw - 1 - s_bw // 2, sh - 1 - s_bw // 2)],
            radius=s_radius,
            fill=fill_color,
            outline=border_color,
            width=s_bw
        )
    else:
        draw.rounded_rectangle(
            [(0, 0), (sw - 1, sh - 1)],
            radius=s_radius,
            fill=fill_color
        )

    img = img.resize((w, h), Image.Resampling.LANCZOS)

    r = radius
    cw = w - 2 * r
    ch = h - 2 * r

    slices = {
        "nw": img.crop((0, 0, r, r)),
        "n": img.crop((r, 0, r + cw, r)),
        "ne": img.crop((r + cw, 0, w, r)),
        "w": img.crop((0, r, r, r + ch)),
        "c": img.crop((r, r, r + cw, r + ch)),
        "e": img.crop((r + cw, r, w, r + ch)),
        "sw": img.crop((0, r + ch, r, h)),
        "s": img.crop((r, r + ch, r + cw, h)),
        "se": img.crop((r + cw, r + ch, w, h)),
    }

    for part, pimg in slices.items():
        out_path = os.path.join(BASE_DIR, f"{name}_{part}.png")
        pimg.save(out_path, "PNG")
        # Also save in pixmaps/ directory for cleanliness
        pimg.save(os.path.join(PIXMAPS_DIR, f"{name}_{part}.png"), "PNG")
    print(f"Generated 9-slice: {name}")

def create_3slice_horizontal(name, size, fill_color, border_color=None):
    """
    Creates a 3-slice horizontal bar (w, c, e).
    """
    w, h = size
    r = h // 2
    scale = 4
    sw, sh = w * scale, h * scale
    s_r = r * scale

    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if border_color:
        draw.rounded_rectangle([(0, 0), (sw - 1, sh - 1)], radius=s_r, fill=fill_color, outline=border_color, width=scale)
    else:
        draw.rounded_rectangle([(0, 0), (sw - 1, sh - 1)], radius=s_r, fill=fill_color)

    img = img.resize((w, h), Image.Resampling.LANCZOS)

    cw = w - 2 * r
    slices = {
        "w": img.crop((0, 0, r, h)),
        "c": img.crop((r, 0, r + cw, h)),
        "e": img.crop((r + cw, 0, w, h)),
    }

    for part, pimg in slices.items():
        out_path = os.path.join(BASE_DIR, f"{name}_{part}.png")
        pimg.save(out_path, "PNG")
        pimg.save(os.path.join(PIXMAPS_DIR, f"{name}_{part}.png"), "PNG")
    print(f"Generated 3-slice (H): {name}")

def create_3slice_vertical(name, size, fill_color):
    """
    Creates a 3-slice vertical bar (n, c, s).
    """
    w, h = size
    r = w // 2
    scale = 4
    sw, sh = w * scale, h * scale
    s_r = r * scale

    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([(0, 0), (sw - 1, sh - 1)], radius=s_r, fill=fill_color)
    img = img.resize((w, h), Image.Resampling.LANCZOS)

    ch = h - 2 * r
    slices = {
        "n": img.crop((0, 0, w, r)),
        "c": img.crop((0, r, w, r + ch)),
        "s": img.crop((0, r + ch, w, h)),
    }

    for part, pimg in slices.items():
        out_path = os.path.join(BASE_DIR, f"{name}_{part}.png")
        pimg.save(out_path, "PNG")
        pimg.save(os.path.join(PIXMAPS_DIR, f"{name}_{part}.png"), "PNG")
    print(f"Generated 3-slice (V): {name}")

def generate_default_background():
    """
    Generates a default blurred dark background or copies from wallpaper.
    """
    bg_path = os.path.join(BASE_DIR, "background.png")
    # If wallpaper exists in ~/.wallpaper, pick one and apply subtle blur
    wall_dir = "/home/Krish/.wallpaper"
    chosen_wall = None
    if os.path.isdir(wall_dir):
        files = [os.path.join(wall_dir, f) for f in os.listdir(wall_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        if files:
            chosen_wall = files[0]

    if chosen_wall and os.path.isfile(chosen_wall):
        try:
            im = Image.open(chosen_wall).convert("RGBA")
            im = im.resize((1920, 1080), Image.Resampling.LANCZOS)
            # Apply subtle dark tint & slight blur matching SilentSDDM lock screen
            dark_overlay = Image.new("RGBA", (1920, 1080), (10, 12, 18, 120))
            im = Image.alpha_composite(im, dark_overlay)
            im.save(bg_path, "PNG")
            print(f"Generated background from wallpaper: {chosen_wall}")
            return
        except Exception as e:
            print(f"Could not load wallpaper: {e}")

    # Fallback to dark gradient
    im = Image.new("RGBA", (1920, 1080), (15, 17, 26, 255))
    draw = ImageDraw.Draw(im)
    for y in range(1080):
        alpha = int(15 + (y / 1080.0) * 20)
        draw.line([(0, y), (1920, y)], fill=(alpha, alpha + 5, alpha + 15, 255))
    im.save(bg_path, "PNG")
    print("Generated fallback dark gradient background.")

def generate_all():
    print("Generating SilentGRUB theme pixmaps...")
    
    # 1. Selected item pill: Sleek translucent white highlight with subtle 1px border & 8px radius
    create_9slice(
        name="select",
        size=(36, 36),
        radius=8,
        fill_color=(255, 255, 255, 38),     # 15% white fill
        border_color=(255, 255, 255, 90),   # 35% white border
        border_width=1
    )

    # 2. Menu box container: Sleek translucent dark glass panel with 12px radius
    create_9slice(
        name="menu_box",
        size=(48, 48),
        radius=12,
        fill_color=(12, 14, 20, 135),       # ~53% dark fill
        border_color=(255, 255, 255, 28),   # ~11% subtle border
        border_width=1
    )

    # 3. Terminal box: Clean terminal container
    create_9slice(
        name="terminal_box",
        size=(40, 40),
        radius=10,
        fill_color=(10, 12, 18, 220),
        border_color=(255, 255, 255, 35),
        border_width=1
    )

    # 4. Progress bar (timeout)
    create_3slice_horizontal(
        name="progress_bar",
        size=(24, 6),
        fill_color=(255, 255, 255, 35)
    )

    create_3slice_horizontal(
        name="progress_highlight",
        size=(24, 6),
        fill_color=(255, 255, 255, 230)
    )

    # 5. Scrollbar slider
    create_3slice_vertical(
        name="slider",
        size=(6, 24),
        fill_color=(255, 255, 255, 80)
    )

    # 6. Generate background
    generate_default_background()

    print("Pixmaps generation complete!")

if __name__ == "__main__":
    generate_all()
