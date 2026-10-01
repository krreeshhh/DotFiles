#!/usr/bin/env python3
"""
Material You (M3) Dynamic Theme Generator for My-Desktop
Extracts rich harmonic tonal palettes from the current wallpaper and distributes
the dynamic Material You tokens across:
- Waybar
- Waybar Popups (Quick Settings, Wi-Fi, Bluetooth, Brightness)
- Logout / Power Menu Screen (nwg-bar)
- App Launcher & Wallpaper Picker (Rofi)
- Notifications (Dunst)
- Kitty Terminal
"""

import sys
import os
import json
import colorsys
from PIL import Image

THEME_DIR = os.path.expanduser("~/.config/my-desktop/theme")
WALLPAPER_DIR_CFG = os.path.expanduser("~/.config/my-desktop/wallpaper")
LAUNCHER_DIR_CFG = os.path.expanduser("~/.config/my-desktop/launcher")
ROFI_DIR_CFG = os.path.expanduser("~/.config/rofi")
DEFAULT_WALLPAPER = os.path.expanduser("~/.wallpaper/Wall.png")

def rgb_to_hex(r, g, b):
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"

def rgb_to_hsl(r, g, b):
    return colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)

def hsl_to_rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return int(r * 255), int(g * 255), int(b * 255)

def hex_to_rgb_str(hex_val):
    h = hex_val.lstrip("#")
    r = int(h[0:2], 16)
    g = int(h[2:4], 16)
    b = int(h[4:6], 16)
    return f"{r},{g},{b}"

def find_nearest_gnome_accent(hex_color):
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    accents = {
        "blue": (53, 132, 228),
        "teal": (33, 144, 164),
        "green": (58, 148, 74),
        "yellow": (200, 136, 0),
        "orange": (237, 91, 0),
        "red": (230, 45, 66),
        "pink": (213, 97, 153),
        "purple": (145, 65, 172),
        "slate": (111, 131, 150),
    }
    return min(accents.items(), key=lambda a: (r - a[1][0])**2 + (g - a[1][1])**2 + (b - a[1][2])**2)[0]


def extract_palette(image_path):
    default_palette = {
        "primary": "#8EC5FC",
        "on_primary": "#121417",
        "primary_container": "#1e2d3d",
        "secondary": "#a0c4ff",
        "background": "#141416",
        "surface": "#1e1e22",
        "surface_variant": "#28282e",
        "surface_selected": "#1e2d3d",
        "on_surface": "#FFFFFF",
        "on_surface_variant": "#A5A5AA",
        "outline": "#333338",
        "outline_subtle": "#25252a",
        "error": "#FF6B6B"
    }

    if not os.path.isfile(image_path):
        return default_palette

    try:
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            img.thumbnail((160, 160), Image.Resampling.BICUBIC)
            
            quantized = img.quantize(colors=32, method=Image.Quantize.MEDIANCUT)
            palette = quantized.getpalette()[:96]
            color_counts = quantized.getcolors()
            
            scored_colors = []
            for count, index in color_counts:
                r = palette[index * 3]
                g = palette[index * 3 + 1]
                b = palette[index * 3 + 2]
                h, l, s = rgb_to_hsl(r, g, b)
                
                if 0.12 < l < 0.88 and s > 0.10:
                    # Weight by saturation and luminance balance
                    score = (s ** 1.4) * (1.0 - abs(l - 0.55)) * (count ** 0.5)
                    scored_colors.append((score, (r, g, b), (h, l, s)))

            if not scored_colors:
                scored_colors = [(count, (palette[idx*3], palette[idx*3+1], palette[idx*3+2]), rgb_to_hsl(palette[idx*3], palette[idx*3+1], palette[idx*3+2])) for count, idx in color_counts]

            scored_colors.sort(key=lambda x: x[0], reverse=True)
            
            # Primary Material You accent (Tone 75-80 for dark mode)
            _, (pr, pg, pb), (ph, pl, ps) = scored_colors[0]
            target_l = max(0.70, min(0.82, pl if pl > 0.5 else pl + 0.35))
            target_s = max(0.45, min(0.85, ps))
            pr, pg, pb = hsl_to_rgb(ph, target_l, target_s)
            primary_hex = rgb_to_hex(pr, pg, pb)
            
            # Secondary accent
            if len(scored_colors) > 1:
                _, _, (sh, sl, ss) = scored_colors[1]
                sr, sg, sb = hsl_to_rgb(sh, 0.75, max(0.35, ss))
                secondary_hex = rgb_to_hex(sr, sg, sb)
            else:
                sr, sg, sb = hsl_to_rgb((ph + 0.08) % 1.0, 0.75, target_s * 0.7)
                secondary_hex = rgb_to_hex(sr, sg, sb)

            # Material You Dark Tinted Surfaces (Tone 6-16 with wallpaper hue)
            bg_r, bg_g, bg_b = hsl_to_rgb(ph, 0.07, min(0.12, ps * 0.25))
            bg_hex = rgb_to_hex(bg_r, bg_g, bg_b)

            surf_r, surf_g, surf_b = hsl_to_rgb(ph, 0.11, min(0.14, ps * 0.28))
            surf_hex = rgb_to_hex(surf_r, surf_g, surf_b)

            surf_v_r, surf_v_g, surf_v_b = hsl_to_rgb(ph, 0.15, min(0.16, ps * 0.30))
            surf_v_hex = rgb_to_hex(surf_v_r, surf_v_g, surf_v_b)

            # Active / Selected container (Tone 20-25 with primary tint)
            sel_r, sel_g, sel_b = hsl_to_rgb(ph, 0.18, min(0.42, ps * 0.65))
            selected_hex = rgb_to_hex(sel_r, sel_g, sel_b)

            # Subtle outline
            out_r, out_g, out_b = hsl_to_rgb(ph, 0.22, min(0.16, ps * 0.30))
            outline_hex = rgb_to_hex(out_r, out_g, out_b)

            return {
                "primary": primary_hex,
                "on_primary": "#121214",
                "primary_container": selected_hex,
                "secondary": secondary_hex,
                "background": bg_hex,
                "surface": surf_hex,
                "surface_variant": surf_v_hex,
                "surface_selected": selected_hex,
                "on_surface": "#FFFFFF",
                "on_surface_variant": "#A5A5AA",
                "outline": outline_hex,
                "outline_subtle": "#25252a",
                "error": "#FF6B6B"
            }
    except Exception as e:
        sys.stderr.write(f"Error extracting palette: {e}\n")
        return default_palette

def generate_theme_files(palette, wallpaper_path):
    for d in [THEME_DIR, WALLPAPER_DIR_CFG, LAUNCHER_DIR_CFG, ROFI_DIR_CFG]:
        os.makedirs(d, exist_ok=True)
    
    if "gnome_accent" not in palette and "primary" in palette:
        palette["gnome_accent"] = find_nearest_gnome_accent(palette["primary"])
    
    # 1. JSON
    with open(os.path.join(THEME_DIR, "colors.json"), "w") as f:
        json.dump({"wallpaper": wallpaper_path, "colors": palette}, f, indent=2)

    # 2. Shell Environment Conf
    with open(os.path.join(THEME_DIR, "colors.conf"), "w") as f:
        f.write("# Material You Desktop Palette\n")
        f.write(f"WALLPAPER=\"{wallpaper_path}\"\n")
        for k, v in palette.items():
            f.write(f"{k.upper()}=\"{v}\"\n")

    # 3. CSS (Waybar / GTK / NWG-Bar / Popups)
    with open(os.path.join(THEME_DIR, "colors.css"), "w") as f:
        f.write("/* Material You Unified CSS Variables */\n")
        f.write(f"@define-color theme_primary {palette['primary']};\n")
        f.write(f"@define-color theme_on_primary {palette['on_primary']};\n")
        f.write(f"@define-color theme_primary_container {palette['primary_container']};\n")
        f.write(f"@define-color theme_secondary {palette['secondary']};\n")
        f.write(f"@define-color theme_bg {palette['background']};\n")
        f.write(f"@define-color theme_surface {palette['surface']};\n")
        f.write(f"@define-color theme_surface_variant {palette['surface_variant']};\n")
        f.write(f"@define-color theme_surface_selected {palette['surface_selected']};\n")
        f.write(f"@define-color theme_on_surface {palette['on_surface']};\n")
        f.write(f"@define-color theme_on_surface_variant {palette['on_surface_variant']};\n")
        f.write(f"@define-color theme_border {palette['outline']};\n")
        f.write(f"@define-color theme_error {palette['error']};\n")

    # 4. Hyprland Lua Table
    with open(os.path.join(THEME_DIR, "colors.lua"), "w") as f:
        f.write("-- Generated Colors for Hyprland Lua\n")
        f.write("return {\n")
        f.write(f"    primary = \"{palette['primary']}\",\n")
        f.write(f"    background = \"{palette['background']}\",\n")
        f.write(f"    surface = \"{palette['surface']}\",\n")
        f.write(f"    error = \"{palette['error']}\",\n")
        f.write("}\n")

    # 5. Kitty Terminal Colors
    with open(os.path.join(THEME_DIR, "colors-kitty.conf"), "w") as f:
        f.write("# Material You Kitty Theme\n")
        f.write(f"foreground {palette['on_surface']}\n")
        f.write(f"background {palette['background']}\n")
        f.write(f"selection_foreground {palette['background']}\n")
        f.write(f"selection_background {palette['primary']}\n")
        f.write(f"cursor {palette['primary']}\n")
        f.write(f"active_border_color {palette['primary']}\n")
        f.write(f"inactive_border_color {palette['outline']}\n")
        f.write(f"color4 {palette['primary']}\n")
        f.write(f"color12 {palette['primary']}\n")

    # 6. Wallpaper Picker RASI Theme
    picker_rasi = f"""/**
 * Wallpaper Picker RASI Theme - Dynamic Material You
 **/
* {{
    bg:           {palette['background']};
    bg-card:      {palette['surface']};
    bg-hover:     {palette['surface_variant']};
    bg-selected:  {palette['surface_selected']};
    fg:           {palette['on_surface']};
    fg-alt:       {palette['on_surface_variant']};
    accent:       {palette['primary']};
    border-subtle: {palette['outline']};

    font: "JetBrainsMono Nerd Font 10";
    background-color: transparent;
    text-color: @fg;
    margin: 0;
    padding: 0;
}}

window {{
    width: 880px;
    height: 540px;
    background-color: @bg;
    border: 1px;
    border-color: @border-subtle;
    border-radius: 14px;
    padding: 20px;
    location: center;
    anchor: center;
}}

mainbox {{
    spacing: 16px;
    children: [ inputbar, listview ];
}}

inputbar {{
    background-color: @bg-card;
    border: 1px;
    border-color: @border-subtle;
    border-radius: 10px;
    padding: 10px 14px;
    spacing: 12px;
    children: [ prompt, entry ];
}}

prompt {{
    text-color: @accent;
    font: "JetBrainsMono Nerd Font Bold 10.5";
}}

entry {{
    text-color: @fg;
    placeholder: "Search wallpapers...";
    placeholder-color: @fg-alt;
}}

listview {{
    columns: 4;
    lines: 2;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    layout: vertical;
    flow: horizontal;
    spacing: 14px;
}}

element {{
    background-color: @bg-card;
    border: 1px;
    border-color: @border-subtle;
    border-radius: 10px;
    padding: 10px;
    spacing: 8px;
    orientation: vertical;
    children: [ element-icon, element-text ];
    cursor: pointer;
}}

element-icon {{
    size: 100px;
    horizontal-align: 0.5;
    vertical-align: 0.5;
    border-radius: 8px;
    cursor: pointer;
}}

element-text {{
    horizontal-align: 0.5;
    vertical-align: 0.5;
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 9.5";
    cursor: pointer;
}}

element normal.normal {{
    background-color: transparent;
    text-color: @fg;
}}

element normal.urgent {{
    background-color: @bg-hover;
    text-color: #FF6B6B;
}}

element normal.active {{
    background-color: @bg-card;
    text-color: @accent;
}}

element selected.normal {{
    background-color: @bg-selected;
    border: 1px;
    border-color: @accent;
}}

element selected.normal element-text {{
    text-color: @accent;
    font: "JetBrainsMono Nerd Font Bold 9.5";
}}

element selected.urgent {{
    background-color: @bg-selected;
    border: 1px;
    border-color: #FF6B6B;
}}

element selected.active {{
    background-color: @bg-selected;
    border: 1px;
    border-color: @accent;
}}

element alternate.normal {{
    background-color: transparent;
    text-color: @fg;
}}

element alternate.urgent {{
    background-color: @bg-hover;
    text-color: #FF6B6B;
}}

element alternate.active {{
    background-color: @bg-card;
    text-color: @accent;
}}
"""
    with open(os.path.join(WALLPAPER_DIR_CFG, "picker.rasi"), "w") as f:
        f.write(picker_rasi)

    # 7. App Launcher RASI Theme
    launcher_rasi = f"""/**
 * App Launcher RASI Theme - Spacious Minimal with Separators & Large Typography
 **/
configuration {{
    show-icons: true;
    icon-theme: "Adwaita";
}}

* {{
    bg:           {palette['background']};
    bg-card:      {palette['surface']};
    bg-hover:     {palette['surface_variant']};
    bg-selected:  {palette['surface_selected']};
    fg:           {palette['on_surface']};
    fg-alt:       {palette['on_surface_variant']};
    accent:       {palette['primary']};
    border-subtle: {palette['outline']};
    border-item:   {palette['outline']}44;
    accent-border: {palette['primary']}77;

    font: "JetBrainsMono Nerd Font 13";
    background-color: transparent;
    text-color: @fg;
    margin: 0;
    padding: 0;
}}

window {{
    width: 480px;
    background-color: @bg;
    border: 1.5px;
    border-color: @border-subtle;
    border-radius: 8px;
    padding: 18px 16px;
    location: center;
    anchor: center;
}}

mainbox {{
    spacing: 12px;
    children: [ inputbar, listview ];
}}

inputbar {{
    background-color: transparent;
    border: 0px 0px 1px 0px;
    border-color: @border-subtle;
    padding: 4px 10px 12px 10px;
    margin: 0px 0px 4px 0px;
    children: [ entry ];
}}

entry {{
    text-color: @fg;
    font: "JetBrainsMono Nerd Font 13.5";
    placeholder: "Go..";
    placeholder-color: @fg-alt;
}}

listview {{
    columns: 1;
    lines: 10;
    fixed-height: false;
    fixed-num-lines: false;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    spacing: 6px;
}}

element {{
    background-color: transparent;
    border: 0px 0px 1px 0px;
    border-color: @border-item;
    border-radius: 6px;
    padding: 10px 16px;
    spacing: 16px;
    children: [ element-icon, element-text ];
    cursor: pointer;
}}

element-icon {{
    size: 26px;
    cursor: pointer;
    vertical-align: 0.5;
}}

element-text {{
    background-color: transparent;
    vertical-align: 0.5;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font 13";
    cursor: pointer;
}}

element normal.normal {{
    background-color: transparent;
    text-color: @fg;
}}

element normal.urgent {{
    background-color: @bg-hover;
    text-color: #FF6B6B;
}}

element normal.active {{
    background-color: @bg-card;
    text-color: @accent;
}}

element selected.normal {{
    background-color: @bg-selected;
    border: 1px;
    border-color: @accent-border;
    border-radius: 6px;
}}

element selected.normal element-text {{
    text-color: @accent;
    font: "JetBrainsMono Nerd Font Bold 13";
}}

element selected.urgent {{
    background-color: @bg-selected;
    border-radius: 6px;
}}

element selected.active {{
    background-color: @bg-selected;
    border-radius: 6px;
}}

element alternate.normal {{
    background-color: transparent;
    text-color: @fg;
}}

element alternate.urgent {{
    background-color: @bg-hover;
    text-color: #FF6B6B;
}}

element alternate.active {{
    background-color: @bg-card;
    text-color: @accent;
}}
"""
    with open(os.path.join(LAUNCHER_DIR_CFG, "launcher.rasi"), "w") as f:
        f.write(launcher_rasi)

    with open(os.path.join(ROFI_DIR_CFG, "config.rasi"), "w") as f:
        f.write(launcher_rasi)

    # 8. Walker GTK4 Theme
    walker_dirs = [
        os.path.expanduser("~/.config/walker"),
        os.path.expanduser("~/.config/walker/themes/default"),
        os.path.expanduser("~/.config/walker/themes/material-you"),
    ]
    for wdir in walker_dirs:
        os.makedirs(wdir, exist_ok=True)

    walker_css = f"""/**
 * Walker Material You Theme - Minimal Clean Aesthetic
 **/
@define-color window_bg_color {palette['background']};
@define-color card_bg_color {palette['surface']};
@define-color hover_bg_color {palette['surface_variant']};
@define-color selected_bg_color {palette['surface_selected']};
@define-color accent_color {palette['primary']};
@define-color text_color {palette['on_surface']};
@define-color subtext_color {palette['on_surface_variant']};
@define-color border_color {palette['outline']};
@define-color error_color {palette['error']};

* {{
  all: unset;
  font-family: 'JetBrainsMono Nerd Font', monospace, sans-serif;
}}

.normal-icons {{
  -gtk-icon-size: 20px;
}}

.large-icons {{
  -gtk-icon-size: 24px;
}}

scrollbar {{
  opacity: 0;
}}

.box-wrapper {{
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);
  background: @window_bg_color;
  padding: 16px 14px 14px 14px;
  border-radius: 4px;
  border: 1.5px solid @border_color;
}}

.preview-box,
.elephant-hint,
.placeholder {{
  color: @subtext_color;
  font-size: 12px;
  padding: 8px;
}}

.search-container {{
  background: transparent;
  border: none;
  padding: 0 4px 6px 4px;
  margin-bottom: 4px;
}}

.input placeholder {{
  color: @accent_color;
  opacity: 0.85;
}}

.input selection {{
  background: @selected_bg_color;
  color: @accent_color;
}}

.input {{
  caret-color: @accent_color;
  background: transparent;
  padding: 2px 4px;
  color: @text_color;
  font-size: 13.5px;
  font-weight: 700;
}}

.list {{
  color: @text_color;
}}

.item-box {{
  background: transparent;
  border-radius: 4px;
  padding: 6px 10px;
  margin: 1px 0;
  border: 1px solid transparent;
  transition: all 0.12s ease;
}}

child:selected .item-box,
row:selected .item-box {{
  background: @selected_bg_color;
  border: 1px solid alpha(@accent_color, 0.35);
}}

child:hover .item-box,
row:hover .item-box {{
  background: @hover_bg_color;
}}

.item-text-box {{
  margin-left: 8px;
}}

.item-text {{
  color: @text_color;
  font-weight: 500;
  font-size: 12.5px;
}}

child:selected .item-text,
row:selected .item-text {{
  color: @accent_color;
  font-weight: 600;
}}

.item-subtext {{
  font-size: 0px;
  min-height: 0px;
  margin: 0px;
  padding: 0px;
  opacity: 0;
}}

.item-quick-activation {{
  display: none;
}}

.keybinds {{
  display: none;
}}

.error {{
  padding: 8px 12px;
  background: @error_color;
  color: #FFFFFF;
  border-radius: 4px;
}}
"""
    for wdir in walker_dirs:
        with open(os.path.join(wdir, "style.css"), "w") as f:
            f.write(walker_css)

    # 9. Clipse Material You Theme
    clipse_dir = os.path.expanduser("~/.config/clipse")
    if os.path.isdir(clipse_dir):
        clipse_theme = {
            "useCustom": True,
            "TitleFore": palette.get("on_primary", "#ffffff"),
            "TitleBack": palette["primary"],
            "TitleInfo": palette["secondary"],
            "NormalTitle": palette["on_surface"],
            "DimmedTitle": palette["on_surface_variant"],
            "SelectedTitle": palette["primary"],
            "NormalDesc": palette["on_surface_variant"],
            "DimmedDesc": palette["on_surface_variant"],
            "SelectedDesc": palette["primary"],
            "StatusMsg": palette["primary"],
            "PinIndicatorColor": palette["primary"],
            "SelectedBorder": palette["primary"],
            "SelectedDescBorder": palette["primary"],
            "FilteredMatch": palette["primary"],
            "FilterPrompt": palette["primary"],
            "FilterInfo": palette["secondary"],
            "FilterText": palette["on_surface"],
            "FilterCursor": palette["primary"],
            "HelpKey": palette["secondary"],
            "HelpDesc": palette["on_surface_variant"],
            "PageActiveDot": palette["primary"],
            "PageInactiveDot": palette["outline"],
            "DividerDot": palette.get("outline_subtle", palette["outline"]),
            "PreviewedText": palette["on_surface"],
            "PreviewBorder": palette["primary"]
        }
        with open(os.path.join(clipse_dir, "custom_theme.json"), "w") as f:
            json.dump(clipse_theme, f, indent=4)

    # 10. Hyprland Dynamic Window Border Theme
    with open(os.path.join(THEME_DIR, "colors-hyprland.conf"), "w") as f:
        f.write(f"# Material You Hyprland Borders\n")
        f.write(f"$primary = rgb({palette['primary'].lstrip('#')})\n")
        f.write(f"$secondary = rgb({palette['secondary'].lstrip('#')})\n")
        f.write(f"$surface = rgb({palette['surface'].lstrip('#')})\n")
        f.write(f"$outline = rgb({palette['outline'].lstrip('#')})\n")
        f.write(f"$active_border = rgb({palette['primary'].lstrip('#')}) rgb({palette['secondary'].lstrip('#')}) 45deg\n")
        f.write(f"$inactive_border = rgba({palette['outline'].lstrip('#')}aa)\n")

    with open(os.path.join(THEME_DIR, "colors-hyprland.lua"), "w") as f:
        f.write("return {\n")
        f.write(f"    primary = \"{palette['primary']}\",\n")
        f.write(f"    secondary = \"{palette['secondary']}\",\n")
        f.write(f"    surface = \"{palette['surface']}\",\n")
        f.write(f"    outline = \"{palette['outline']}\",\n")
        f.write("}\n")

    # 11. KDE / Dolphin Material You Color Scheme (kdeglobals & color-schemes)
    pri_rgb = hex_to_rgb_str(palette['primary'])
    on_pri_rgb = hex_to_rgb_str(palette.get('on_primary', '#121214'))
    sec_rgb = hex_to_rgb_str(palette['secondary'])
    bg_rgb = hex_to_rgb_str(palette['background'])
    surf_rgb = hex_to_rgb_str(palette['surface'])
    surf_v_rgb = hex_to_rgb_str(palette.get('surface_variant', '#28282e'))
    out_rgb = hex_to_rgb_str(palette['outline'])

    kdeglobals_content = f"""[General]
ColorScheme=MaterialYou
Name=Material You Dark
TerminalApplication=ghostty
shadeSortColumn=true

[KDE]
colorScheme=MaterialYou
contrast=4

[Icons]
Theme=WhiteSur-dark

[Colors:Window]
BackgroundNormal={bg_rgb}
BackgroundAlternate={surf_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170
ForegroundLink={pri_rgb}
ForegroundVisited={sec_rgb}
ForegroundNegative=255,107,107
ForegroundPositive=140,220,140

[Colors:View]
BackgroundNormal={bg_rgb}
BackgroundAlternate={surf_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170
ForegroundLink={pri_rgb}
ForegroundVisited={sec_rgb}
ForegroundNegative=255,107,107
ForegroundPositive=140,220,140

[Colors:Button]
BackgroundNormal={surf_rgb}
BackgroundAlternate={surf_v_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170
ForegroundLink={pri_rgb}
ForegroundVisited={sec_rgb}

[Colors:Selection]
BackgroundNormal={pri_rgb}
BackgroundAlternate={sec_rgb}
ForegroundNormal={on_pri_rgb}
ForegroundInactive={on_pri_rgb}
ForegroundLink={on_pri_rgb}
ForegroundVisited={on_pri_rgb}

[Colors:Tooltip]
BackgroundNormal={surf_rgb}
BackgroundAlternate={surf_v_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170

[Colors:Complementary]
BackgroundNormal={bg_rgb}
BackgroundAlternate={surf_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170
ForegroundLink={pri_rgb}
ForegroundVisited={sec_rgb}

[Colors:Header]
BackgroundNormal={surf_rgb}
BackgroundAlternate={surf_v_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170
ForegroundLink={pri_rgb}
ForegroundVisited={sec_rgb}

[Colors:Header:Window]
BackgroundNormal={surf_rgb}
BackgroundAlternate={surf_v_rgb}
ForegroundNormal=255,255,255
ForegroundInactive=165,165,170

[WM]
activeBackground={surf_rgb}
activeBlend={pri_rgb}
activeForeground=255,255,255
inactiveBackground={bg_rgb}
inactiveBlend={surf_rgb}
inactiveForeground=165,165,170

[Wallet]
Enabled=false
"""

    kdeglobals_path = os.path.expanduser("~/.config/kdeglobals")
    with open(kdeglobals_path, "w") as f:
        f.write(kdeglobals_content)

    color_schemes_dir = os.path.expanduser("~/.local/share/color-schemes")
    os.makedirs(color_schemes_dir, exist_ok=True)
    with open(os.path.join(color_schemes_dir, "MaterialYou.colors"), "w") as f:
        f.write(kdeglobals_content)

    # 12. GTK 3, GTK 4, and Ghostty Material You Theme
    gtk3_css_path = os.path.expanduser("~/.config/gtk-3.0/gtk.css")
    gtk4_css_path = os.path.expanduser("~/.config/gtk-4.0/gtk.css")
    ghostty_css_path = os.path.expanduser("~/.config/ghostty/gtk.css")
    
    error_color = palette.get("error", "#ff6b6b")
    surf_var = palette.get("surface_variant", "#28282e")
    outline_col = palette.get("outline", "#333338")
    
    gtk_css_content = f"""/* =========================================================
 * Material You (M3) GTK 3/4 & Ghostty Theme
 * ========================================================= */

@define-color accent_color {palette['primary']};
@define-color accent_bg_color {palette['primary']};
@define-color accent_fg_color {palette.get('on_primary', '#121417')};
@define-color theme_selected_bg_color {palette['primary']};
@define-color theme_selected_fg_color {palette.get('on_primary', '#121417')};
@define-color destructive_color {error_color};
@define-color destructive_bg_color {error_color};
@define-color destructive_fg_color #ffffff;
@define-color error_color {error_color};
@define-color theme_fg_color {palette['on_surface']};
@define-color theme_text_color {palette['on_surface']};
@define-color theme_bg_color {palette['background']};
@define-color theme_base_color {palette['background']};
@define-color theme_unfocused_fg_color {palette['on_surface']};
@define-color theme_unfocused_text_color {palette['on_surface']};
@define-color theme_unfocused_bg_color {palette['background']};
@define-color theme_unfocused_base_color {palette['background']};

@define-color window_bg_color {palette['background']};
@define-color window_fg_color {palette['on_surface']};
@define-color view_bg_color {palette['background']};
@define-color view_fg_color {palette['on_surface']};
@define-color headerbar_bg_color {palette['surface']};
@define-color headerbar_fg_color {palette['on_surface']};
@define-color headerbar_backdrop_color {palette['background']};
@define-color sidebar_bg_color {palette['surface']};
@define-color sidebar_fg_color {palette['on_surface']};
@define-color sidebar_backdrop_color {palette['background']};
@define-color secondary_sidebar_bg_color {palette['surface']};
@define-color secondary_sidebar_fg_color {palette['on_surface']};
@define-color card_bg_color {palette['surface']};
@define-color card_fg_color {palette['on_surface']};
@define-color popover_bg_color {palette['surface']};
@define-color popover_fg_color {palette['on_surface']};
@define-color dialog_bg_color {palette['surface']};
@define-color dialog_fg_color {palette['on_surface']};
@define-color surface_variant {surf_var};
@define-color outline_color {outline_col};

/* Libadwaita Dark Mode override */
@media (prefers-color-scheme: dark) {{
    @define-color accent_color {palette['primary']};
    @define-color accent_bg_color {palette['primary']};
    @define-color accent_fg_color {palette.get('on_primary', '#121417')};
    @define-color window_bg_color {palette['background']};
    @define-color window_fg_color {palette['on_surface']};
    @define-color view_bg_color {palette['background']};
    @define-color view_fg_color {palette['on_surface']};
    @define-color headerbar_bg_color {palette['surface']};
    @define-color headerbar_fg_color {palette['on_surface']};
    @define-color headerbar_backdrop_color {palette['background']};
    @define-color sidebar_bg_color {palette['surface']};
    @define-color sidebar_fg_color {palette['on_surface']};
    @define-color sidebar_backdrop_color {palette['background']};
    @define-color secondary_sidebar_bg_color {palette['surface']};
    @define-color secondary_sidebar_fg_color {palette['on_surface']};
    @define-color card_bg_color {palette['surface']};
    @define-color card_fg_color {palette['on_surface']};
    @define-color dialog_bg_color {palette['surface']};
    @define-color dialog_fg_color {palette['on_surface']};
    @define-color popover_bg_color {palette['surface']};
    @define-color popover_fg_color {palette['on_surface']};
}}

/* CSS Custom Properties for Libadwaita & Nautilus */
:root,
window,
.nautilus-window {{
    --accent-color: {palette['primary']};
    --accent-bg-color: {palette['primary']};
    --accent-fg-color: {palette.get('on_primary', '#121417')};
    --window-bg-color: {palette['background']};
    --window-fg-color: {palette['on_surface']};
    --view-bg-color: {palette['background']};
    --view-fg-color: {palette['on_surface']};
    --headerbar-bg-color: {palette['surface']};
    --headerbar-fg-color: {palette['on_surface']};
    --headerbar-backdrop-color: {palette['background']};
    --sidebar-bg-color: {palette['surface']};
    --sidebar-fg-color: {palette['on_surface']};
    --sidebar-backdrop-color: {palette['background']};
    --secondary-sidebar-bg-color: {palette['surface']};
    --secondary-sidebar-fg-color: {palette['on_surface']};
    --card-bg-color: {palette['surface']};
    --card-fg-color: {palette['on_surface']};
    --dialog-bg-color: {palette['surface']};
    --dialog-fg-color: {palette['on_surface']};
    --popover-bg-color: {palette['surface']};
    --popover-fg-color: {palette['on_surface']};
    --border-color: {outline_col};
}}

/* --- Global Window, Dialog & View Base --- */
window,
dialog,
messagedialog,
filechooser,
.background {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

view,
iconview,
treeview,
.view,
textview,
textview text,
list,
listview,
gridview,
row {{
    color: @theme_text_color;
    background-color: @view_bg_color;
}}

view:selected,
iconview:selected,
treeview:selected,
.view:selected,
list:selected,
listview:selected,
gridview:selected,
row:selected {{
    color: @theme_selected_fg_color;
    background-color: @theme_selected_bg_color;
}}

placessidebar,
.navigation-sidebar,
placessidebar list,
.navigation-sidebar list,
placessidebar viewport,
.navigation-sidebar viewport {{
    background-color: @sidebar_bg_color;
    color: @sidebar_fg_color;
}}

placessidebar row,
.navigation-sidebar row {{
    color: @sidebar_fg_color;
}}

placessidebar row:selected,
.navigation-sidebar row:selected {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}}

/* --- Headerbar unification --- */
headerbar,
headerbar.flat,
.navigation-sidebar headerbar,
splitview headerbar,
.top-bar {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    background-image: none;
    box-shadow: none;
}}

headerbar:backdrop,
.navigation-sidebar headerbar:backdrop {{
    background-color: @headerbar_backdrop_color;
    background-image: none;
}}

/* =========================================================
 * Nautilus File Manager - Material You Dynamic Theme
 * Strictly manages theme colors; preserves UI layout & alignment
 * ========================================================= */

window.nautilus-window,
.nautilus-window,
window.view {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

.nautilus-window headerbar,
.nautilus-window AdwHeaderBar,
.nautilus-window .top-bar {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    box-shadow: none;
    border-bottom: 1px solid alpha(@outline_color, 0.30);
}}

.nautilus-window splitview > AdwToolbarView:first-child,
.nautilus-window .navigation-sidebar,
.nautilus-window placessidebar {{
    background-color: @sidebar_bg_color;
    color: @sidebar_fg_color;
    border-right: 1px solid alpha(@outline_color, 0.30);
}}

.nautilus-window .navigation-sidebar row:selected,
.nautilus-window placessidebar row:selected {{
    background-color: @accent_bg_color;
    color: @accent_fg_color;
    font-weight: 600;
}}

.nautilus-window .navigation-sidebar row:hover:not(:selected),
.nautilus-window placessidebar row:hover:not(:selected) {{
    background-color: alpha(@accent_color, 0.14);
}}

.nautilus-window .view,
.nautilus-window AdwTabView,
.nautilus-window .nautilus-list-view,
.nautilus-window .nautilus-grid-view,
.nautilus-window .nautilus-network-view {{
    background-color: @view_bg_color;
    color: @theme_text_color;
}}

/* Override Nautilus internal grey accent on views */
.nautilus-window .nautilus-list-view listview,
.nautilus-window .nautilus-grid-view gridview,
.nautilus-window .nautilus-network-view listview {{
    --accent-bg-color: @accent_bg_color;
    --accent-color: @accent_color;
    --accent-fg-color: @accent_fg_color;
}}

/* Material You Grid Selection & Hover */
.nautilus-window .nautilus-grid-view gridview > child:selected {{
    background-color: alpha(@accent_bg_color, 0.30);
    outline: none;
    border: none;
    color: @theme_fg_color;
}}

.nautilus-window .nautilus-grid-view gridview > child:hover:not(:selected) {{
    background-color: alpha(@accent_bg_color, 0.12);
}}

/* Material You Column / List Selection & Hover */
.nautilus-window .nautilus-list-view columnview > listview > row:selected {{
    background-color: alpha(@accent_bg_color, 0.30);
    outline: none;
    border: none;
    color: @theme_fg_color;
}}

.nautilus-window .nautilus-list-view columnview > listview > row:hover:not(:selected) {{
    background-color: alpha(@accent_bg_color, 0.12);
}}

/* Material You Pathbar / Breadcrumbs */
.nautilus-window .nautilus-pathbar {{
    background-color: alpha(@surface_variant, 0.70);
    border: 1px solid alpha(@outline_color, 0.35);
}}

.nautilus-window .nautilus-path-button:hover {{
    background-color: alpha(@accent_bg_color, 0.22);
    color: @accent_color;
}}

.nautilus-window .nautilus-path-button.current-dir {{
    color: @accent_color;
    font-weight: 700;
}}

/* Material You Search & Query Bar */
.nautilus-window .nautilus-query-editor {{
    background-color: alpha(@surface_variant, 0.80);
}}

/* Floating Status Bar */
.nautilus-window .floating-bar {{
    background-color: alpha(@surface_variant, 0.95);
    color: @window_fg_color;
    border: 1px solid alpha(@outline_color, 0.50);
}}

.nautilus-window .disk-space-used {{
    color: @accent_color;
    font-weight: bold;
}}


/* =========================================================
 * Material You Popovers, Dropdown & Context Menus
 * ========================================================= */

popover,
popover.background {{
    background-color: transparent;
    padding: 0;
}}

popover > arrow,
popover > contents,
popover.menu > contents,
.popover > contents,
menubutton popover > contents,
popover.background > contents,
.nautilus-window popover > contents,
.nautilus-window popover.menu > contents {{
    background-color: @card_bg_color;
    background-image: none;
    opacity: 1.0;
    color: @theme_fg_color;
    border: 1px solid alpha(@outline_color, 0.45);
    border-radius: 12px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.75), 0 2px 8px rgba(0, 0, 0, 0.50);
    padding: 6px;
}}

popover > arrow,
.nautilus-window popover > arrow {{
    background-color: @card_bg_color;
    border-color: alpha(@outline_color, 0.45);
}}

popover.menu list,
popover.menu listview,
popover list,
popover listview,
.nautilus-window popover listview,
.nautilus-window popover list {{
    background-color: transparent;
    background: transparent;
    color: inherit;
}}

popover.menu modelbutton,
popover.menu list > row,
popover.menu listview > row,
popover modelbutton,
.nautilus-window popover modelbutton,
.nautilus-window popover listview > row {{
    color: @theme_fg_color;
    border-radius: 6px;
    min-height: 32px;
    padding: 4px 10px;
    background-color: transparent;
}}

popover.menu modelbutton:hover,
popover.menu modelbutton:selected,
popover.menu list > row:hover,
popover.menu listview > row:hover,
popover modelbutton:hover,
.nautilus-window popover modelbutton:hover,
.nautilus-window popover listview > row:hover {{
    background-color: alpha(@accent_color, 0.20);
    color: @accent_color;
}}

popover.menu modelbutton:active,
popover.menu list > row:active,
popover.menu listview > row:active,
popover modelbutton:active,
.nautilus-window popover modelbutton:active,
.nautilus-window popover listview > row:active {{
    background-color: alpha(@accent_color, 0.32);
    color: @accent_color;
}}

popover separator,
popover.menu separator,
.nautilus-window popover separator {{
    background-color: alpha(@outline_color, 0.40);
    margin: 4px 6px;
    min-height: 1px;
}}

popover.menu accelerator,
popover accelerator,
accelerator {{
    color: alpha(@theme_fg_color, 0.60);
    font-size: 0.85em;
    margin-left: 20px;
}}


/* =========================================================
 * Material You Dialogs & Close Confirmation Modals (Quickshell Glass Match)
 * ========================================================= */

dialog,
window.dialog,
alertdialog,
adw-alert-dialog,
adw-dialog,
.dialog-sheet,
sheet,
.GhosttyCloseConfirmationDialog,
.clipboard-confirmation-dialog {{
    background-color: transparent;
    font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace, sans-serif;
}}

/* Floating Modal Box / Card */
dialog > contents,
dialog > .dialog-content,
window.dialog > contents,
alertdialog > contents,
adw-alert-dialog > contents,
.dialog-sheet,
sheet,
.GhosttyCloseConfirmationDialog > contents,
.clipboard-confirmation-dialog > contents {{
    background-color: alpha(@dialog_bg_color, 0.88);
    background-image: none;
    color: @dialog_fg_color;
    border-radius: 12px;
    border: 1.5px solid alpha(@accent_color, 0.40);
    box-shadow: 0 16px 36px rgba(0, 0, 0, 0.60), 0 0 1px 1px alpha(@accent_color, 0.15);
    padding: 16px 20px;
    font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace, sans-serif;
}}

/* Dimmer / backdrop */
dimmer,
.dimmer {{
    background-color: rgba(0, 0, 0, 0.55);
}}

/* Dialog Titles & Headings */
dialog .heading,
alertdialog .heading,
adw-alert-dialog .heading,
.GhosttyCloseConfirmationDialog .heading,
dialog .title,
dialog headerbar .title {{
    font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace, sans-serif;
    font-weight: 700;
    font-size: 1.12rem;
    color: @dialog_fg_color;
    margin-top: 2px;
    margin-bottom: 6px;
    letter-spacing: -0.2px;
}}

/* Dialog Body / Description */
dialog .body,
alertdialog .body,
adw-alert-dialog .body,
.GhosttyCloseConfirmationDialog .body {{
    font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace, sans-serif;
    font-size: 0.85rem;
    color: alpha(@dialog_fg_color, 0.72);
    margin-bottom: 14px;
}}

/* Action Buttons (Standard / Cancel) - Compact Size */
dialog button,
alertdialog button,
adw-alert-dialog button,
.dialog-action-area button,
.dialog-buttons button,
.GhosttyCloseConfirmationDialog button {{
    font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace, sans-serif;
    border-radius: 6px;
    font-weight: 600;
    font-size: 0.82rem;
    padding: 5px 16px;
    margin: 2px 4px;
    min-height: 28px;
    min-width: 70px;
    transition: all 150ms cubic-bezier(0.4, 0, 0.2, 1);
    background-color: alpha(@surface_variant, 0.85);
    color: @dialog_fg_color;
    border: 1px solid alpha(@outline_color, 0.50);
    box-shadow: none;
}}

dialog button:hover,
alertdialog button:hover,
adw-alert-dialog button:hover,
.GhosttyCloseConfirmationDialog button:hover {{
    background-color: alpha(@accent_color, 0.18);
    border-color: @accent_color;
    color: @accent_color;
    box-shadow: 0 2px 8px alpha(@accent_color, 0.20);
}}

dialog button:active,
alertdialog button:active,
adw-alert-dialog button:active,
.GhosttyCloseConfirmationDialog button:active {{
    background-color: alpha(@accent_color, 0.28);
}}

/* Close / Destructive Button - Compact Size */
dialog button.destructive-action,
alertdialog button.destructive-action,
adw-alert-dialog button.destructive-action,
.GhosttyCloseConfirmationDialog button.destructive-action {{
    background: alpha(@error_color, 0.90);
    color: #121214;
    font-weight: 700;
    border: 1px solid alpha(@error_color, 0.95);
    box-shadow: 0 3px 10px alpha(@error_color, 0.30);
}}

dialog button.destructive-action:hover,
alertdialog button.destructive-action:hover,
adw-alert-dialog button.destructive-action:hover,
.GhosttyCloseConfirmationDialog button.destructive-action:hover {{
    background: @error_color;
    color: #ffffff;
    border-color: #ffa0a0;
    box-shadow: 0 4px 14px alpha(@error_color, 0.50);
}}

dialog button.destructive-action:active,
alertdialog button.destructive-action:active,
adw-alert-dialog button.destructive-action:active,
.GhosttyCloseConfirmationDialog button.destructive-action:active {{
    background: #d94545;
}}

/* Suggested / Primary Action Button */
dialog button.suggested-action,
alertdialog button.suggested-action,
adw-alert-dialog button.suggested-action,
.GhosttyCloseConfirmationDialog button.suggested-action {{
    background: @accent_color;
    color: @accent_fg_color;
    font-weight: 700;
    border: 1px solid @accent_color;
    box-shadow: 0 3px 10px alpha(@accent_color, 0.30);
}}

dialog button.suggested-action:hover,
alertdialog button.suggested-action:hover,
adw-alert-dialog button.suggested-action:hover,
.GhosttyCloseConfirmationDialog button.suggested-action:hover {{
    background: alpha(@accent_color, 0.95);
    box-shadow: 0 6px 18px alpha(@accent_color, 0.55);
}}
"""
    # Write GTK 3 CSS
    gtk3_css_content = f"""/* =========================================================
 * Material You (M3) GTK 3 Theme
 * ========================================================= */

@define-color accent_color {palette['primary']};
@define-color accent_bg_color {palette['primary']};
@define-color accent_fg_color {palette.get('on_primary', '#121417')};
@define-color theme_selected_bg_color {palette['primary']};
@define-color theme_selected_fg_color {palette.get('on_primary', '#121417')};
@define-color destructive_color {error_color};
@define-color destructive_bg_color {error_color};
@define-color destructive_fg_color #ffffff;
@define-color error_color {error_color};
@define-color theme_fg_color {palette['on_surface']};
@define-color theme_text_color {palette['on_surface']};
@define-color theme_bg_color {palette['background']};
@define-color theme_base_color {palette['background']};
@define-color theme_unfocused_fg_color {palette['on_surface']};
@define-color theme_unfocused_text_color {palette['on_surface']};
@define-color theme_unfocused_bg_color {palette['background']};
@define-color theme_unfocused_base_color {palette['background']};

@define-color window_bg_color {palette['background']};
@define-color window_fg_color {palette['on_surface']};
@define-color view_bg_color {palette['background']};
@define-color view_fg_color {palette['on_surface']};
@define-color headerbar_bg_color {palette['surface']};
@define-color headerbar_fg_color {palette['on_surface']};
@define-color sidebar_bg_color {palette['surface']};
@define-color sidebar_fg_color {palette['on_surface']};
@define-color card_bg_color {palette['surface']};
@define-color card_fg_color {palette['on_surface']};
@define-color dialog_bg_color {palette['surface']};
@define-color dialog_fg_color {palette['on_surface']};
@define-color surface_variant {surf_var};
@define-color outline_color {outline_col};

window,
dialog,
messagedialog,
filechooser,
.background {{
    background-color: @window_bg_color;
    color: @window_fg_color;
}}

view,
iconview,
treeview,
.view,
textview,
textview text,
list,
row {{
    color: @theme_text_color;
    background-color: @view_bg_color;
}}

view:selected,
iconview:selected,
treeview:selected,
.view:selected,
list:selected,
row:selected {{
    color: @theme_selected_fg_color;
    background-color: @theme_selected_bg_color;
}}

/* Places Sidebar / Navigation */
placessidebar,
.navigation-sidebar {{
    background-color: @sidebar_bg_color;
    color: @sidebar_fg_color;
    border-right: 1px solid alpha(@outline_color, 0.30);
}}

placessidebar list,
placessidebar viewport,
.navigation-sidebar list,
.navigation-sidebar viewport {{
    background-color: transparent;
}}

placessidebar row,
.navigation-sidebar row {{
    color: @sidebar_fg_color;
    border-radius: 6px;
    margin: 2px 4px;
}}

placessidebar row:selected,
.navigation-sidebar row:selected {{
    background-color: @accent_bg_color;
    color: @accent_fg_color;
    font-weight: 600;
}}

placessidebar row:hover:not(:selected),
.navigation-sidebar row:hover:not(:selected) {{
    background-color: alpha(@accent_color, 0.14);
}}

/* Headerbar */
headerbar,
headerbar.titlebar {{
    background-color: @headerbar_bg_color;
    color: @headerbar_fg_color;
    border-bottom: 1px solid alpha(@outline_color, 0.30);
    box-shadow: none;
}}

/* File Chooser Dialog & Treeview */
filechooser treeview.view,
treeview.view {{
    background-color: @view_bg_color;
    color: @theme_text_color;
}}

filechooser treeview.view:selected,
treeview.view:selected {{
    background-color: alpha(@accent_bg_color, 0.30);
    color: @theme_fg_color;
    outline: none;
}}

filechooser treeview.view:hover:not(:selected),
treeview.view:hover:not(:selected) {{
    background-color: alpha(@accent_bg_color, 0.12);
}}

treeview header button {{
    background-color: @headerbar_bg_color;
    color: @theme_text_color;
    border: none;
    border-bottom: 1px solid alpha(@outline_color, 0.30);
    font-weight: 600;
}}

treeview header button:hover {{
    background-color: alpha(@surface_variant, 0.90);
    color: @accent_color;
}}

/* Buttons */
button {{
    border-radius: 6px;
    background-color: alpha(@surface_variant, 0.85);
    color: @dialog_fg_color;
    border: 1px solid alpha(@outline_color, 0.50);
    transition: all 150ms cubic-bezier(0.4, 0, 0.2, 1);
}}

button:hover {{
    background-color: alpha(@accent_color, 0.18);
    border-color: @accent_color;
    color: @accent_color;
}}

button:active {{
    background-color: alpha(@accent_color, 0.28);
}}

button.suggested-action {{
    background-color: @accent_color;
    color: @accent_fg_color;
    font-weight: 700;
    border: 1px solid @accent_color;
}}

button.suggested-action:hover {{
    background-color: alpha(@accent_color, 0.95);
}}

button.destructive-action {{
    background-color: alpha(@error_color, 0.90);
    color: #ffffff;
    font-weight: 700;
    border: 1px solid alpha(@error_color, 0.95);
}}

button.destructive-action:hover {{
    background-color: @error_color;
}}

/* Entry & Search */
entry {{
    background-color: alpha(@surface_variant, 0.80);
    color: @window_fg_color;
    border: 1px solid alpha(@outline_color, 0.50);
    border-radius: 6px;
    padding: 4px 8px;
}}

entry:focus {{
    border-color: @accent_color;
}}

/* Pathbar */
.path-bar button,
path-bar button {{
    background-color: alpha(@surface_variant, 0.70);
    border-radius: 6px;
    color: @window_fg_color;
}}

.path-bar button:hover,
path-bar button:hover {{
    background-color: alpha(@accent_bg_color, 0.22);
    color: @accent_color;
}}

.path-bar button:checked,
path-bar button:checked {{
    color: @accent_color;
    font-weight: 700;
}}

/* Scrollbars */
scrollbar slider {{
    background-color: alpha(@outline_color, 0.60);
    border-radius: 4px;
}}

scrollbar slider:hover {{
    background-color: alpha(@accent_color, 0.60);
}}
"""
    os.makedirs(os.path.dirname(gtk3_css_path), exist_ok=True)
    with open(gtk3_css_path, "w") as f:
        f.write(gtk3_css_content)

    # Write GTK 4 and Ghostty CSS
    for p in [gtk4_css_path, ghostty_css_path]:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(gtk_css_content)


    # Ensure GTK settings.ini enforces dark mode with valid built-in Adwaita theme and macOS WhiteSur icons
    gtk_settings_ini = """[Settings]
gtk-theme-name = Adwaita
gtk-icon-theme-name = WhiteSur-dark
gtk-application-prefer-dark-theme = 1
gtk-cursor-theme-name = Bibata-Modern-Ice
gtk-cursor-theme-size = 24
gtk-font-name = Adwaita Sans 11
gtk-decoration-layout = :close
"""
    for p in [
        os.path.expanduser("~/.config/gtk-3.0/settings.ini"),
        os.path.expanduser("~/.config/gtk-4.0/settings.ini"),
    ]:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(gtk_settings_ini)

def main():
    if len(sys.argv) > 1:
        wallpaper = sys.argv[1]
    else:
        state_file = os.path.expanduser("~/.config/my-desktop/wallpaper/current")
        if os.path.isfile(state_file):
            with open(state_file, "r") as f:
                wallpaper = f.read().strip()
        else:
            wallpaper = DEFAULT_WALLPAPER

    palette = extract_palette(wallpaper)
    generate_theme_files(palette, wallpaper)
    print(f"Theme generated successfully for: {wallpaper}")
    print(f"Primary Accent: {palette['primary']} | Background: {palette['background']} | Surface: {palette['surface']}")

if __name__ == "__main__":
    main()
