#!/usr/bin/env python3
"""
ASUS TUF Gaming Armoury Crate - Keyboard Lighting Controller
Streamlined interface themed dynamically with desktop Material You colors.
Controls ASUS TUF Gaming A15 RGB keyboard backlight via kernel sysfs.
Buttons and controls dynamically reflect the backlight's active Material You color.
"""

import sys
import os
import math
import colorsys
import json
from pathlib import Path
from typing import Dict, Any, Tuple, Optional

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import cairo

from backend import TufKeyboardBackend, MODES, SPEEDS, hex_to_rgb

THEME_FILE_PATH = Path.home() / ".config" / "my-desktop" / "theme" / "colors.json"


def load_material_you_palette() -> Dict[str, Any]:
    """Loads active Material You theme extracted from current wallpaper."""
    if THEME_FILE_PATH.exists():
        try:
            with open(THEME_FILE_PATH, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "wallpaper": "Wallpaper",
        "colors": {
            "primary": "#d88cad",
            "secondary": "#a8acd5",
            "primary_container": "#3c1e2b",
            "background": "#130f11",
            "surface": "#1f181b",
            "surface_variant": "#2b2025",
            "outline": "#402f36",
            "on_surface": "#FFFFFF",
            "on_surface_variant": "#A5A5AA"
        }
    }


def generate_css(pal: Dict[str, Any], accent_override: Optional[str] = None) -> str:
    cols = pal.get("colors", {})
    primary = accent_override if accent_override else cols.get("primary", "#d88cad")
    secondary = cols.get("secondary", "#a8acd5")
    pri_container = cols.get("primary_container", "#3c1e2b")
    bg = cols.get("background", "#130f11")
    surface = cols.get("surface", "#1f181b")
    surf_variant = cols.get("surface_variant", "#2b2025")
    outline = cols.get("outline", "#402f36")

    # If accent was overridden to a custom color, calculate a complementary container
    if accent_override and accent_override != cols.get("primary"):
        r, g, b = hex_to_rgb(accent_override)
        pri_container = f"rgba({r}, {g}, {b}, 0.22)"

    return f"""
/* Material You Dynamic Desktop Theming */
window.armoury-crate-window {{
    background-color: {bg};
    color: #F0F2F6;
    font-family: 'Segoe UI', 'Ubuntu', 'Sans Serif';
}}

.nav-tab-btn {{
    background: transparent;
    border: none;
    border-bottom: 3px solid transparent;
    border-radius: 0;
    color: #8E96A6;
    font-size: 14px;
    font-weight: 700;
    padding: 8px 20px;
}}
.nav-tab-btn:hover {{
    color: #FFFFFF;
    border-bottom: 3px solid {outline};
}}
.nav-tab-btn.active {{
    color: #FFFFFF;
    border-bottom: 3px solid {primary};
}}

.panel-card {{
    background-color: {surface};
    border: 1px solid {outline};
    border-radius: 8px;
    padding: 18px;
}}

.section-header {{
    color: {primary};
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 1.5px;
}}

.effect-card {{
    background-color: {surf_variant};
    border: 1px solid {outline};
    border-radius: 6px;
    padding: 12px 14px;
    transition: all 150ms ease-in-out;
}}
.effect-card:hover {{
    background-color: #352830;
    border-color: #553e49;
}}
.effect-card.active {{
    background: linear-gradient(to right, {pri_container}, {surface});
    border: 1.5px solid {primary};
}}

.material-you-card {{
    background-color: {pri_container};
    border: 1.5px solid {primary};
    border-radius: 6px;
    padding: 8px 12px;
}}

.speed-btn {{
    background-color: {surf_variant};
    border: 1px solid {outline};
    border-radius: 4px;
    color: #D2D7E0;
    font-weight: 600;
    padding: 6px 16px;
}}
.speed-btn:hover {{
    background-color: #352830;
    color: #FFFFFF;
}}
.speed-btn.active {{
    background-color: {primary};
    border-color: {primary};
    color: #0E1015;
    font-weight: 700;
}}

.btn-apply-primary {{
    background-color: {primary};
    color: #0E1015;
    border: 1px solid {primary};
    border-radius: 4px;
    font-weight: 700;
    font-size: 13px;
    padding: 8px 22px;
}}
.btn-apply-primary:hover {{
    background-color: {secondary};
}}

.btn-secondary {{
    background-color: {surf_variant};
    color: #D2D7E0;
    border: 1px solid {outline};
    border-radius: 4px;
    padding: 7px 16px;
}}
.btn-secondary:hover {{
    background-color: #352830;
    color: #FFFFFF;
    border-color: {primary};
}}

.swatch-btn {{
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 4px;
    min-width: 26px;
    min-height: 26px;
    padding: 0;
}}
.swatch-btn:hover {{
    border: 2px solid #FFFFFF;
}}

.status-badge {{
    background-color: {surface};
    border: 1px solid {outline};
    border-radius: 14px;
    padding: 4px 12px;
}}

scale trough {{
    background-color: {bg};
    border: 1px solid {outline};
    border-radius: 3px;
    min-height: 6px;
}}
scale highlight {{
    background-color: {primary};
    border-radius: 3px;
}}
scale slider {{
    background-color: #FFFFFF;
    border: 2px solid {primary};
    border-radius: 8px;
    min-width: 16px;
    min-height: 16px;
}}

checkbutton check {{
    background-color: {bg};
    border: 1px solid {outline};
    border-radius: 3px;
    min-width: 16px;
    min-height: 16px;
}}
checkbutton:checked check {{
    background-color: {primary};
    border-color: {primary};
    color: #0E1015;
}}

/* Switch & Slider / Button Styling */
switch {{
    background-color: {surf_variant};
    border: 1.5px solid {outline};
    border-radius: 14px;
    min-width: 44px;
    min-height: 24px;
    padding: 2px;
}}
switch:checked {{
    background-color: {pri_container};
    border-color: {primary};
}}
switch slider {{
    background-color: #6C7485;
    border-radius: 10px;
    min-width: 18px;
    min-height: 18px;
    margin: 2px;
}}
switch:checked slider {{
    background-color: {primary};
    border-radius: 10px;
    min-width: 18px;
    min-height: 18px;
    margin: 2px;
    box-shadow: 0 0 8px {primary};
}}
"""


class TufKeyboardVisualizer(Gtk.DrawingArea):
    """
    Interactive ASUS TUF Gaming A15 Laptop Keyboard Visualizer
    Renders deck, keyboard matrix, translucent WASD keys, and live lighting animations.
    """
    def __init__(self, primary_accent: str = "#d88cad"):
        super().__init__()
        self.set_content_width(580)
        self.set_content_height(154)
        self.set_draw_func(self._draw_func)

        self.accent_rgb = hex_to_rgb(primary_accent)
        self.mode = 0  # 0: Static, 1: Breathing, 2: Cycle, 3: Strobe
        self.r = self.accent_rgb[0] / 255.0
        self.g = self.accent_rgb[1] / 255.0
        self.b = self.accent_rgb[2] / 255.0
        self.speed = 1
        self.brightness = 3

        self.anim_phase = 0.0
        self.strobe_state = True
        self.strobe_counter = 0

        GLib.timeout_add(16, self._on_tick)

    def set_accent_color(self, hex_code: str):
        self.accent_rgb = hex_to_rgb(hex_code)
        self.queue_draw()

    def update_state(self, mode: int, r: int, g: int, b: int, speed: int, brightness: int):
        self.mode = mode
        self.r = r / 255.0
        self.g = g / 255.0
        self.b = b / 255.0
        self.speed = speed
        self.brightness = brightness
        self.queue_draw()

    def _on_tick(self) -> bool:
        speed_mult = [0.02, 0.045, 0.08][self.speed]
        self.anim_phase += speed_mult
        if self.anim_phase > 2 * math.pi:
            self.anim_phase -= 2 * math.pi

        strobe_ticks = [18, 10, 5][self.speed]
        self.strobe_counter += 1
        if self.strobe_counter >= strobe_ticks:
            self.strobe_counter = 0
            self.strobe_state = not self.strobe_state

        self.queue_draw()
        return True

    def _get_key_rgb(self, col_offset: float = 0.0) -> Tuple[float, float, float]:
        if self.brightness == 0:
            return (0.07, 0.08, 0.10)

        bri_factor = [0.0, 0.45, 0.75, 1.0][self.brightness]

        if self.mode == 0:  # Static
            return (self.r * bri_factor, self.g * bri_factor, self.b * bri_factor)

        elif self.mode == 1:  # Breathing
            factor = (math.sin(self.anim_phase) + 1.0) / 2.0
            factor = (0.15 + 0.85 * factor) * bri_factor
            return (self.r * factor, self.g * factor, self.b * factor)

        elif self.mode == 2:  # Color Cycle
            hue = (self.anim_phase / (2 * math.pi) + col_offset) % 1.0
            r, g, b = colorsys.hsv_to_rgb(hue, 0.95, bri_factor)
            return (r, g, b)

        elif self.mode == 3:  # Strobing
            if self.strobe_state:
                return (self.r * bri_factor, self.g * bri_factor, self.b * bri_factor)
            else:
                return (0.05, 0.06, 0.08)

        return (self.r, self.g, self.b)

    def _draw_func(self, area, cr, width, height):
        w = width
        h = height

        deck_pad_x = 10
        deck_pad_y = 6
        deck_w = w - 20
        deck_h = h - 12
        radius = 8

        # 1. Deck base
        cr.new_sub_path()
        cr.arc(deck_pad_x + deck_w - radius, deck_pad_y + radius, radius, -math.pi/2, 0)
        cr.arc(deck_pad_x + deck_w - radius, deck_pad_y + deck_h - radius, radius, 0, math.pi/2)
        cr.arc(deck_pad_x + radius, deck_pad_y + deck_h - radius, radius, math.pi/2, math.pi)
        cr.arc(deck_pad_x + radius, deck_pad_y + radius, radius, math.pi, 3*math.pi/2)
        cr.close_path()

        pat = cairo.LinearGradient(0, 0, 0, h)
        pat.add_color_stop_rgb(0.0, 0.08, 0.10, 0.12)
        pat.add_color_stop_rgb(0.5, 0.06, 0.07, 0.09)
        pat.add_color_stop_rgb(1.0, 0.04, 0.05, 0.07)
        cr.set_source(pat)
        cr.fill_preserve()

        cr.set_source_rgb(0.18, 0.20, 0.24)
        cr.set_line_width(1.2)
        cr.stroke()

        # Chamfers in Active Backlight/Material You accent
        ar, ag, ab = self.accent_rgb[0] / 255.0, self.accent_rgb[1] / 255.0, self.accent_rgb[2] / 255.0
        cr.set_source_rgb(ar, ag, ab)
        cr.set_line_width(1.5)
        cr.move_to(14, 18)
        cr.line_to(22, 10)
        cr.stroke()
        cr.move_to(w - 14, 18)
        cr.line_to(w - 22, 10)
        cr.stroke()

        # 2. Keyboard Well
        well_x = 24
        well_y = 18
        well_w = w - 48
        well_h = h - 36
        w_rad = 5

        cr.new_sub_path()
        cr.arc(well_x + well_w - w_rad, well_y + w_rad, w_rad, -math.pi/2, 0)
        cr.arc(well_x + well_w - w_rad, well_y + well_h - w_rad, w_rad, 0, math.pi/2)
        cr.arc(well_x + w_rad, well_y + well_h - w_rad, w_rad, math.pi/2, math.pi)
        cr.arc(well_x + w_rad, well_y + w_rad, w_rad, math.pi, 3*math.pi/2)
        cr.close_path()

        cr.set_source_rgb(0.03, 0.04, 0.05)
        cr.fill_preserve()
        cr.set_source_rgb(0.02, 0.03, 0.03)
        cr.set_line_width(2.0)
        cr.stroke()

        # 3. Diffused Ambient RGB Underglow
        center_r, center_g, center_b = self._get_key_rgb(0.5)
        glow_pat = cairo.RadialGradient(w / 2, h / 2, 10, w / 2, h / 2, w * 0.45)
        glow_pat.add_color_stop_rgba(0.0, center_r, center_g, center_b, 0.55)
        glow_pat.add_color_stop_rgba(0.7, center_r, center_g, center_b, 0.22)
        glow_pat.add_color_stop_rgba(1.0, 0, 0, 0, 0.0)
        cr.rectangle(well_x, well_y, well_w, well_h)
        cr.set_source(glow_pat)
        cr.fill()

        # 4. Keyboard Keycaps Matrix
        rows = 6
        cols = 16
        kw = (well_w - 12) / cols
        kh = (well_h - 12) / rows

        for r_idx in range(rows):
            for c_idx in range(cols):
                kx = well_x + 6 + c_idx * kw
                ky = well_y + 6 + r_idx * kh
                kr_w = kw - 2.5
                kr_h = kh - 2.5

                col_offset = (c_idx / cols) * 0.7
                kr, kg, kb = self._get_key_rgb(col_offset)

                is_wasd = (r_idx == 2 and c_idx == 2) or (r_idx == 3 and c_idx in (1, 2, 3))

                cr.rectangle(kx, ky, kr_w, kr_h)
                if is_wasd:
                    cr.set_source_rgba(0.92, 0.95, 1.0, 0.65)
                    cr.fill_preserve()
                    cr.set_source_rgb(kr, kg, kb)
                    cr.set_line_width(1.5)
                    cr.stroke()
                else:
                    cr.set_source_rgb(0.08, 0.09, 0.12)
                    cr.fill_preserve()
                    cr.set_source_rgba(kr, kg, kb, 0.7)
                    cr.set_line_width(0.8)
                    cr.stroke()

                cr.arc(kx + kr_w / 2, ky + kr_h / 2, 1.5, 0, 2 * math.pi)
                cr.set_source_rgb(kr, kg, kb)
                cr.fill()

        # Badge in Accent
        cr.set_source_rgb(ar, ag, ab)
        cr.select_font_face("Sans Serif", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(8)
        cr.move_to(w - 140, 14)
        cr.show_text("TUF GAMING A15")


class ColorWheelWidget(Gtk.DrawingArea):
    """
    Interactive 2D Saturation-Value box and Hue selector bar.
    """
    def __init__(self, on_change_callback):
        super().__init__()
        self.set_content_width(220)
        self.set_content_height(150)
        self.set_draw_func(self._draw_func)
        self.on_change = on_change_callback

        self.current_hue = 0.92  # Default to active Material You hue
        self.current_sat = 0.35
        self.current_val = 0.85
        self.is_dragging_sv = False
        self.is_dragging_hue = False

        click_gesture = Gtk.GestureClick()
        click_gesture.connect("pressed", self._on_pressed)
        click_gesture.connect("released", self._on_released)
        self.add_controller(click_gesture)

        motion_controller = Gtk.EventControllerMotion()
        motion_controller.connect("motion", self._on_motion)
        self.add_controller(motion_controller)

    def set_rgb(self, r: int, g: int, b: int):
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        self.current_hue = h
        self.current_sat = s
        self.current_val = v
        self.queue_draw()

    def get_rgb(self) -> Tuple[int, int, int]:
        r, g, b = colorsys.hsv_to_rgb(self.current_hue, self.current_sat, self.current_val)
        return int(r * 255), int(g * 255), int(b * 255)

    def _draw_func(self, area, cr, width, height):
        w = width
        h = height

        sv_w = w - 34
        sv_h = h - 8
        sv_x = 4
        sv_y = 4

        br, bg, bb = colorsys.hsv_to_rgb(self.current_hue, 1.0, 1.0)

        # 1. SV Box: Horizontal white-to-hue gradient
        h_pat = cairo.LinearGradient(sv_x, 0, sv_x + sv_w, 0)
        h_pat.add_color_stop_rgb(0.0, 1.0, 1.0, 1.0)
        h_pat.add_color_stop_rgb(1.0, br, bg, bb)
        cr.rectangle(sv_x, sv_y, sv_w, sv_h)
        cr.set_source(h_pat)
        cr.fill()

        # Vertical transparent-to-black gradient
        v_pat = cairo.LinearGradient(0, sv_y, 0, sv_y + sv_h)
        v_pat.add_color_stop_rgba(0.0, 0, 0, 0, 0.0)
        v_pat.add_color_stop_rgba(1.0, 0, 0, 0, 1.0)
        cr.rectangle(sv_x, sv_y, sv_w, sv_h)
        cr.set_source(v_pat)
        cr.fill()

        cr.rectangle(sv_x, sv_y, sv_w, sv_h)
        cr.set_source_rgb(0.18, 0.22, 0.26)
        cr.set_line_width(1.2)
        cr.stroke()

        # SV Cursor Target
        cx = sv_x + self.current_sat * sv_w
        cy = sv_y + (1.0 - self.current_val) * sv_h
        cur_r, cur_g, cur_b = self.get_rgb()

        cr.arc(cx, cy, 6, 0, 2 * math.pi)
        cr.set_source_rgb(0, 0, 0)
        cr.set_line_width(2.5)
        cr.stroke_preserve()
        cr.set_source_rgb(cur_r / 255.0, cur_g / 255.0, cur_b / 255.0)
        cr.fill_preserve()
        cr.arc(cx, cy, 7, 0, 2 * math.pi)
        cr.set_source_rgb(1.0, 1.0, 1.0)
        cr.set_line_width(1.2)
        cr.stroke()

        # 2. Hue Bar Area
        hue_x = w - 22
        hue_y = 4
        hue_w = 18
        hue_h = h - 8

        hue_pat = cairo.LinearGradient(0, hue_y, 0, hue_y + hue_h)
        for step in range(7):
            h_val = step / 6.0
            hr, hg, hb = colorsys.hsv_to_rgb(h_val, 1.0, 1.0)
            hue_pat.add_color_stop_rgb(h_val, hr, hg, hb)

        cr.rectangle(hue_x, hue_y, hue_w, hue_h)
        cr.set_source(hue_pat)
        cr.fill()

        cr.rectangle(hue_x, hue_y, hue_w, hue_h)
        cr.set_source_rgb(0.18, 0.22, 0.26)
        cr.set_line_width(1.2)
        cr.stroke()

        # Hue Pointer
        hy = hue_y + self.current_hue * hue_h
        cr.rectangle(hue_x - 2, hy - 3, hue_w + 4, 6)
        cr.set_source_rgb(1.0, 1.0, 1.0)
        cr.set_line_width(2.0)
        cr.stroke_preserve()
        cr.set_source_rgb(br, bg, bb)
        cr.fill()

    def _on_pressed(self, gesture, n_press, x, y):
        w = self.get_width()
        sv_w = w - 34
        if x <= sv_w + 4:
            self.is_dragging_sv = True
            self._update_sv(x, y)
        else:
            self.is_dragging_hue = True
            self._update_hue(y)

    def _on_released(self, gesture, n_press, x, y):
        self.is_dragging_sv = False
        self.is_dragging_hue = False

    def _on_motion(self, controller, x, y):
        if self.is_dragging_sv:
            self._update_sv(x, y)
        elif self.is_dragging_hue:
            self._update_hue(y)

    def _update_sv(self, x, y):
        w = self.get_width()
        h = self.get_height()
        sv_w = w - 34
        sv_h = h - 8
        self.current_sat = max(0.0, min(1.0, (x - 4) / sv_w))
        self.current_val = max(0.0, min(1.0, 1.0 - (y - 4) / sv_h))
        self.queue_draw()
        if self.on_change:
            r, g, b = self.get_rgb()
            self.on_change(r, g, b)

    def _update_hue(self, y):
        h = self.get_height()
        hue_h = h - 8
        self.current_hue = max(0.0, min(1.0, (y - 4) / hue_h))
        self.queue_draw()
        if self.on_change:
            r, g, b = self.get_rgb()
            self.on_change(r, g, b)


class EffectCard(Gtk.Box):
    def __init__(self, mode_id: int, title: str, subtitle: str, icon_str: str, on_click_callback):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        self.mode_id = mode_id
        self.on_click = on_click_callback
        self.add_css_class("effect-card")
        self.set_cursor(Gdk.Cursor.new_from_name("pointer"))

        self.icon_lbl = Gtk.Label()
        self.icon_lbl.set_markup(f"<span size='x-large'>{icon_str}</span>")
        self.append(self.icon_lbl)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.title_lbl = Gtk.Label(label=title, xalign=0)
        self.title_lbl.set_markup(f"<b>{title}</b>")
        text_box.append(self.title_lbl)

        self.sub_lbl = Gtk.Label(label=subtitle, xalign=0)
        self.sub_lbl.set_markup(f"<span size='small' color='#8E96A6'>{subtitle}</span>")
        text_box.append(self.sub_lbl)
        self.append(text_box)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        self.append(spacer)

        self.radio_lbl = Gtk.Label(label="○")
        self.radio_lbl.set_markup("<span color='#4A5266'>○</span>")
        self.append(self.radio_lbl)

        gesture = Gtk.GestureClick()
        gesture.connect("pressed", lambda g, n, x, y: self.on_click(self.mode_id))
        self.add_controller(gesture)

    def set_active(self, active: bool, accent_color: str = "#d88cad"):
        if active:
            self.add_css_class("active")
            self.radio_lbl.set_markup(f"<span color='{accent_color}'>●</span>")
            self.title_lbl.set_markup(f"<span color='#FFFFFF'><b>{self.title_lbl.get_text()}</b></span>")
        else:
            self.remove_css_class("active")
            self.radio_lbl.set_markup("<span color='#4A5266'>○</span>")
            self.title_lbl.set_markup(f"<span color='#D2D7E0'><b>{self.title_lbl.get_text()}</b></span>")


class ArmouryCrateApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.asus.tuf.armoury_crate")
        self.backend = TufKeyboardBackend()
        self.window = None

        self.palette = load_material_you_palette()
        self.primary_hex = self.palette.get("colors", {}).get("primary", "#d88cad")
        self.secondary_hex = self.palette.get("colors", {}).get("secondary", "#a8acd5")
        self.container_hex = self.palette.get("colors", {}).get("primary_container", "#3c1e2b")

        my_r, my_g, my_b = hex_to_rgb(self.primary_hex)

        self.current_mode = self.backend.config.get("mode", 0)
        col = self.backend.config.get("color", [my_r, my_g, my_b])
        self.current_r = col[0]
        self.current_g = col[1]
        self.current_b = col[2]
        self.current_speed = self.backend.config.get("speed", 1)
        self.current_brightness = self.backend.config.get("brightness", 3)
        self.auto_apply = True

        self.css_provider = Gtk.CssProvider()
        self.theme_mtime = THEME_FILE_PATH.stat().st_mtime if THEME_FILE_PATH.exists() else 0

    def do_activate(self):
        if self.window:
            self.window.present()
            return

        # Load initial dynamic CSS matching active Material You
        active_accent = f"#{self.current_r:02X}{self.current_g:02X}{self.current_b:02X}"
        css_data = generate_css(self.palette, active_accent)
        self.css_provider.load_from_data(css_data.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            self.css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.window = Gtk.ApplicationWindow(application=self)
        self.window.set_title("ARMOURY CRATE - ASUS TUF GAMING A15")
        self.window.set_default_size(940, 680)
        self.window.add_css_class("armoury-crate-window")

        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        content_box.set_margin_start(24)
        content_box.set_margin_end(24)
        content_box.set_margin_top(20)
        content_box.set_margin_bottom(18)
        self.window.set_child(content_box)

        # 1. Top Header
        content_box.append(self._create_header())

        # 2. Navigation Tabs
        content_box.append(self._create_tabs())

        # 3. Stacked Views
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_vexpand(True)

        self.stack.add_named(self._create_basic_effects_view(), "effects")
        self.stack.add_named(self._create_settings_view(), "settings")
        content_box.append(self.stack)

        # 4. Live Keyboard Visualizer
        self.visualizer = TufKeyboardVisualizer(primary_accent=active_accent)
        content_box.append(self.visualizer)

        # 5. Footer Bar
        content_box.append(self._create_footer())

        self._sync_to_ui()
        self.window.present()

        # Monitor Material You changes in real-time (every 400ms)
        GLib.timeout_add(400, self._check_live_theme)

    def _check_live_theme(self) -> bool:
        """Polls colors.json so when Material You changes, buttons & backlight update live."""
        if THEME_FILE_PATH.exists():
            try:
                mtime = THEME_FILE_PATH.stat().st_mtime
                if mtime != self.theme_mtime:
                    self.theme_mtime = mtime
                    new_palette = load_material_you_palette()
                    self.palette = new_palette
                    new_pri = new_palette.get("colors", {}).get("primary", "#d88cad")
                    self.primary_hex = new_pri
                    self.secondary_hex = new_palette.get("colors", {}).get("secondary", "#a8acd5")
                    self.container_hex = new_palette.get("colors", {}).get("primary_container", "#3c1e2b")

                    if self.backend.config.get("sync_material_you", True):
                        r, g, b = hex_to_rgb(new_pri)
                        self.current_r = r
                        self.current_g = g
                        self.current_b = b
                        self.backend.apply_material_you(self.current_mode)
                        self._update_accent_theme(new_pri)
                        self._sync_to_ui()
                        self._set_status(f"Material You updated to {new_pri.upper()} - Backlight & Buttons Synced!")
            except Exception as e:
                pass
        return True

    def _update_accent_theme(self, hex_accent: str):
        """Updates all UI buttons, switches, sliders, and highlights to match the backlight color."""
        css_data = generate_css(self.palette, hex_accent)
        self.css_provider.load_from_data(css_data.encode("utf-8"))
        if hasattr(self, 'visualizer'):
            self.visualizer.set_accent_color(hex_accent)
        if hasattr(self, 'my_dot'):
            self.my_dot.set_markup(f"<span color='{hex_accent}'>●</span>")
        if hasattr(self, 'my_t_lbl'):
            self.my_t_lbl.set_markup(f"<span color='#FFFFFF'><b>󰏘 Wallpaper Palette ({self.primary_hex.upper()})</b></span>")

    def _create_header(self) -> Gtk.Widget:
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        bc_lbl = Gtk.Label(label="Device > System > Lighting", xalign=0)
        bc_lbl.set_markup("<span size='small' color='#7E8799'>Device &gt; System &gt; Lighting</span>")
        title_box.append(bc_lbl)

        title_lbl = Gtk.Label(label="TUF GAMING LIGHTING", xalign=0)
        title_lbl.set_markup(f"<span size='x-large' color='#FFFFFF'><b>TUF GAMING LIGHTING</b></span>")
        title_box.append(title_lbl)
        header.append(title_box)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        header.append(spacer)

        # Material You Wallpaper badge
        my_pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        my_pill.add_css_class("status-badge")
        self.my_dot = Gtk.Label()
        self.my_dot.set_markup(f"<span color='{self.primary_hex}'>●</span>")
        self.my_badge_lbl = Gtk.Label()
        self.my_badge_lbl.set_markup(f"<span size='small' color='#D2D7E0'>Material You: <b>{self.primary_hex.upper()}</b></span>")
        my_pill.append(self.my_dot)
        my_pill.append(self.my_badge_lbl)
        header.append(my_pill)

        header.append(Gtk.Box(spacing=8))

        # Hardware Status Badge
        badge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        badge.add_css_class("status-badge")
        dot_lbl = Gtk.Label()
        dot_lbl.set_markup("<span color='#00E676'>●</span>")
        dev_lbl = Gtk.Label()
        dev_lbl.set_markup("<span size='small' color='#E2E6EE'><b>TUF GAMING A15</b></span>")
        badge.append(dot_lbl)
        badge.append(dev_lbl)
        header.append(badge)

        return header

    def _create_tabs(self) -> Gtk.Widget:
        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)

        self.btn_tab_effects = Gtk.Button(label="Basic Effects")
        self.btn_tab_effects.add_css_class("nav-tab-btn")
        self.btn_tab_effects.add_css_class("active")
        self.btn_tab_effects.connect("clicked", lambda b: self._switch_tab("effects"))
        tab_box.append(self.btn_tab_effects)

        self.btn_tab_settings = Gtk.Button(label="Settings")
        self.btn_tab_settings.add_css_class("nav-tab-btn")
        self.btn_tab_settings.connect("clicked", lambda b: self._switch_tab("settings"))
        tab_box.append(self.btn_tab_settings)

        return tab_box

    def _switch_tab(self, name: str):
        self.stack.set_visible_child_name(name)
        if name == "effects":
            self.btn_tab_effects.add_css_class("active")
            self.btn_tab_settings.remove_css_class("active")
        else:
            self.btn_tab_settings.add_css_class("active")
            self.btn_tab_effects.remove_css_class("active")

    def _create_basic_effects_view(self) -> Gtk.Widget:
        view = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)

        left_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        left_panel.add_css_class("panel-card")
        left_panel.set_hexpand(True)

        eff_hdr = Gtk.Label(label="BASIC EFFECTS", xalign=0)
        eff_hdr.add_css_class("section-header")
        left_panel.append(eff_hdr)

        self.effect_cards = {}
        effects_data = [
            (0, "Static", "Single solid color illumination", "󰌵"),
            (1, "Breathing", "Gently fades between colors", "󰛲"),
            (2, "Color Cycle", "Continuous rainbow spectrum loop", "󰑮"),
            (3, "Strobing", "Rapid rhythmic flashing light", "󰖨"),
        ]

        for m_id, title, sub, icon in effects_data:
            card = EffectCard(m_id, title, sub, icon, self._on_card_clicked)
            self.effect_cards[m_id] = card
            left_panel.append(card)

        view.append(left_panel)

        right_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        right_panel.add_css_class("panel-card")
        right_panel.set_hexpand(True)

        # Color Section
        self.color_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        
        c_hdr_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        c_hdr = Gtk.Label(label="COLOR SETTINGS", xalign=0)
        c_hdr.add_css_class("section-header")
        c_hdr_box.append(c_hdr)

        c_spacer = Gtk.Box()
        c_spacer.set_hexpand(True)
        c_hdr_box.append(c_spacer)

        self.hex_label = Gtk.Label()
        self.hex_label.set_markup(f"<span font_family='Monospace' color='#FFFFFF'><b>#{self.current_r:02X}{self.current_g:02X}{self.current_b:02X}</b></span>")
        c_hdr_box.append(self.hex_label)
        self.color_section.append(c_hdr_box)

        # Material You Sync Card Banner
        my_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        my_card.add_css_class("material-you-card")

        my_info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.my_t_lbl = Gtk.Label(xalign=0)
        self.my_t_lbl.set_markup(f"<span color='#FFFFFF'><b>󰏘 Wallpaper Palette ({self.primary_hex.upper()})</b></span>")
        my_info_box.append(self.my_t_lbl)

        wp_base = os.path.basename(self.palette.get("wallpaper", "Wallpaper"))
        my_s_lbl = Gtk.Label(xalign=0)
        my_s_lbl.set_markup(f"<span size='small' color='#D2D7E0'>Active desktop Material You accent</span>")
        my_info_box.append(my_s_lbl)
        my_card.append(my_info_box)

        my_sp = Gtk.Box()
        my_sp.set_hexpand(True)
        my_card.append(my_sp)

        btn_apply_my = Gtk.Button(label="Sync Material You")
        btn_apply_my.add_css_class("btn-apply-primary")
        btn_apply_my.set_cursor(Gdk.Cursor.new_from_name("pointer"))
        btn_apply_my.connect("clicked", lambda b: self._apply_material_you_clicked())
        my_card.append(btn_apply_my)

        self.color_section.append(my_card)

        # Color Wheel & Swatches
        pick_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        self.color_wheel = ColorWheelWidget(self._on_wheel_color_changed)
        pick_box.append(self.color_wheel)

        swatch_grid = Gtk.Grid()
        swatch_grid.set_row_spacing(6)
        swatch_grid.set_column_spacing(6)

        all_swatches = [
            (self.primary_hex, f"Wallpaper Primary ({self.primary_hex.upper()})"),
            (self.secondary_hex, f"Wallpaper Secondary ({self.secondary_hex.upper()})"),
            (self.container_hex, f"Wallpaper Accent ({self.container_hex.upper()})"),
            ("#FFFFFF", "Glacier White"),
            ("#71D9F3", "Cyan Sky"),
            ("#D88CAD", "Tokyo Pink"),
            ("#FF9900", "TUF Amber"),
            ("#FF2020", "Inferno Red"),
            ("#FF5722", "Cyber Coral"),
            ("#FFD700", "Sunburst Gold"),
            ("#76FF03", "Acid Lime"),
            ("#7C4DFF", "Electric Violet"),
        ]

        for i, (hex_code, name) in enumerate(all_swatches):
            row = i // 4
            col = i % 4
            s_btn = Gtk.Button()
            s_btn.add_css_class("swatch-btn")
            s_btn.set_tooltip_text(name)
            s_btn.set_cursor(Gdk.Cursor.new_from_name("pointer"))

            css_sw = Gtk.CssProvider()
            css_sw.load_from_data(f"button {{ background-color: {hex_code}; }}".encode("utf-8"))
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_sw,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

            s_btn.connect("clicked", lambda b, h=hex_code: self._set_color_from_hex(h))
            swatch_grid.attach(s_btn, col, row, 1, 1)

        pick_box.append(swatch_grid)
        self.color_section.append(pick_box)
        right_panel.append(self.color_section)

        # Speed Section
        self.speed_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        s_hdr = Gtk.Label(label="EFFECT SPEED", xalign=0)
        s_hdr.add_css_class("section-header")
        self.speed_section.append(s_hdr)

        speed_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.speed_buttons = {}
        for sp_id, sp_label in SPEEDS.items():
            btn = Gtk.Button(label=sp_label)
            btn.add_css_class("speed-btn")
            btn.set_hexpand(True)
            btn.connect("clicked", lambda b, s=sp_id: self._on_speed_btn_clicked(s))
            self.speed_buttons[sp_id] = btn
            speed_box.append(btn)

        self.speed_section.append(speed_box)
        right_panel.append(self.speed_section)

        # Brightness Section
        bright_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        b_hdr_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        b_hdr = Gtk.Label(label="BRIGHTNESS", xalign=0)
        b_hdr.add_css_class("section-header")
        b_hdr_box.append(b_hdr)

        b_spacer = Gtk.Box()
        b_spacer.set_hexpand(True)
        b_hdr_box.append(b_spacer)

        self.bright_val_lbl = Gtk.Label(label="100%")
        self.bright_val_lbl.set_markup("<span color='#FFFFFF'><b>100%</b></span>")
        b_hdr_box.append(self.bright_val_lbl)
        bright_box.append(b_hdr_box)

        self.bright_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 3, 1)
        self.bright_scale.set_draw_value(False)
        self.bright_scale.connect("value-changed", self._on_brightness_changed)
        bright_box.append(self.bright_scale)

        labels_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        for text in ["Off", "Low (33%)", "Med (66%)", "High (100%)"]:
            lbl = Gtk.Label(label=text)
            lbl.set_markup(f"<span size='x-small' color='#5A6273'>{text}</span>")
            lbl.set_hexpand(True)
            labels_box.append(lbl)
        bright_box.append(labels_box)

        right_panel.append(bright_box)

        view.append(right_panel)
        return view

    def _create_settings_view(self) -> Gtk.Widget:
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        panel.add_css_class("panel-card")

        title = Gtk.Label(label="DEVICE LIGHTING & THEME SYNC", xalign=0)
        title.add_css_class("section-header")
        panel.append(title)

        desc = Gtk.Label(label="Configure lighting states and dynamic desktop wallpaper integration.", xalign=0)
        desc.set_markup("<span size='small' color='#8E96A6'>Configure lighting states and dynamic desktop wallpaper integration.</span>")
        panel.append(desc)

        # Wallpaper Sync Option
        sync_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        sync_lbl = Gtk.Label(label="Auto-sync Keyboard Backlight with Wallpaper Changes", xalign=0)
        sync_lbl.set_markup("<span color='#FFFFFF'><b>Auto-sync Keyboard Backlight with Wallpaper Changes</b></span>")
        sync_lbl.set_hexpand(True)
        sync_row.append(sync_lbl)

        self.sw_sync_my = Gtk.Switch()
        self.sw_sync_my.set_active(self.backend.config.get("sync_material_you", True))
        self.sw_sync_my.connect("state-set", lambda s, state: self._on_sync_my_toggle(state))
        sync_row.append(self.sw_sync_my)
        panel.append(sync_row)

        panel.append(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL))

        pstates = self.backend.config.get("power_states", {"boot": 1, "awake": 1, "sleep": 0})

        self.sw_awake = self._create_switch_row("Laptop Backlight Active (Awake Mode)", bool(pstates.get("awake", 1)))
        panel.append(self.sw_awake)

        self.sw_sleep = self._create_switch_row("Laptop Backlight in Sleep Mode", bool(pstates.get("sleep", 0)))
        panel.append(self.sw_sleep)

        self.sw_boot = self._create_switch_row("Boot up & Shutdown Lighting Sequence", bool(pstates.get("boot", 1)))
        panel.append(self.sw_boot)

        persist_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        persist_box.add_css_class("panel-card")
        persist_box.set_margin_top(12)

        pb_title = Gtk.Label(label="󰒋 Hardware Firmware Persistence", xalign=0)
        pb_title.set_markup("<span color='#FFFFFF'><b>󰒋 Hardware Firmware Persistence</b></span>")
        persist_box.append(pb_title)

        pb_desc = Gtk.Label(xalign=0)
        pb_desc.set_markup("<span size='small' color='#8E96A6'>Settings are written directly to the ASUS TUF embedded controller / WMI BIOS firmware. Lighting preferences persist across system reboots and cold boots.</span>")
        pb_desc.set_wrap(True)
        persist_box.append(pb_desc)

        panel.append(persist_box)
        return panel

    def _create_switch_row(self, label_text: str, default_val: bool) -> Gtk.Widget:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_margin_top(4)
        row.set_margin_bottom(4)

        escaped = label_text.replace("&", "&amp;")
        lbl = Gtk.Label(label=label_text, xalign=0)
        lbl.set_markup(f"<span color='#FFFFFF'>{escaped}</span>")
        lbl.set_hexpand(True)
        row.append(lbl)

        sw = Gtk.Switch()
        sw.set_active(default_val)
        sw.connect("state-set", lambda s, state: self._on_power_state_toggle())
        row.append(sw)
        return row

    def _create_footer(self) -> Gtk.Widget:
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        self.status_lbl = Gtk.Label(label="Ready", xalign=0)
        self.status_lbl.set_markup("<span size='small' color='#788294'>Ready</span>")
        footer.append(self.status_lbl)

        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        footer.append(spacer)

        self.chk_auto = Gtk.CheckButton(label="Auto-Apply Changes")
        self.chk_auto.set_active(True)
        self.chk_auto.connect("toggled", lambda cb: setattr(self, "auto_apply", cb.get_active()))
        footer.append(self.chk_auto)

        btn_reset = Gtk.Button(label="Reset Defaults")
        btn_reset.add_css_class("btn-secondary")
        btn_reset.connect("clicked", lambda b: self._reset_defaults())
        footer.append(btn_reset)

        btn_apply = Gtk.Button(label="󰐥  Apply to Device")
        btn_apply.add_css_class("btn-apply-primary")
        btn_apply.connect("clicked", lambda b: self._apply_all())
        footer.append(btn_apply)

        return footer

    def _sync_to_ui(self):
        active_hex = f"#{self.current_r:02X}{self.current_g:02X}{self.current_b:02X}"
        for m_id, card in self.effect_cards.items():
            card.set_active(m_id == self.current_mode, active_hex)

        self.color_section.set_visible(self.current_mode != 2)
        self.speed_section.set_visible(self.current_mode != 0)

        self.color_wheel.set_rgb(self.current_r, self.current_g, self.current_b)
        self.hex_label.set_markup(f"<span font_family='Monospace' color='#FFFFFF'><b>{active_hex}</b></span>")

        for sp_id, btn in self.speed_buttons.items():
            if sp_id == self.current_speed:
                btn.add_css_class("active")
            else:
                btn.remove_css_class("active")

        self.bright_scale.set_value(self.current_brightness)
        b_pct = ["0%", "33%", "66%", "100%"][self.current_brightness]
        self.bright_val_lbl.set_markup(f"<span color='#FFFFFF'><b>{b_pct}</b></span>")

        self.visualizer.update_state(
            self.current_mode,
            self.current_r,
            self.current_g,
            self.current_b,
            self.current_speed,
            self.current_brightness
        )

    def _apply_material_you_clicked(self):
        r, g, b = hex_to_rgb(self.primary_hex)
        self.current_r = r
        self.current_g = g
        self.current_b = b
        self._update_accent_theme(self.primary_hex)
        self._sync_to_ui()
        self.backend.apply_material_you(self.current_mode)
        self._set_status(f"Synchronized with Material You palette ({self.primary_hex.upper()})")

    def _on_sync_my_toggle(self, state: bool):
        self.backend.config["sync_material_you"] = state
        self.backend.save_config()
        if state:
            self._apply_material_you_clicked()

    def _on_card_clicked(self, mode_id: int):
        self.current_mode = mode_id
        self._sync_to_ui()
        if self.auto_apply:
            self._apply_mode()

    def _on_wheel_color_changed(self, r: int, g: int, b: int):
        self.current_r = r
        self.current_g = g
        self.current_b = b
        hex_str = f"#{r:02X}{g:02X}{b:02X}"
        self.hex_label.set_markup(f"<span font_family='Monospace' color='#FFFFFF'><b>{hex_str}</b></span>")
        self._update_accent_theme(hex_str)
        self.visualizer.update_state(
            self.current_mode,
            self.current_r,
            self.current_g,
            self.current_b,
            self.current_speed,
            self.current_brightness
        )
        if self.auto_apply:
            self._apply_mode()

    def _set_color_from_hex(self, hex_code: str):
        r, g, b = hex_to_rgb(hex_code)
        self.color_wheel.set_rgb(r, g, b)
        self._on_wheel_color_changed(r, g, b)

    def _on_speed_btn_clicked(self, speed_id: int):
        self.current_speed = speed_id
        self._sync_to_ui()
        if self.auto_apply:
            self._apply_mode()

    def _on_brightness_changed(self, scale):
        self.current_brightness = int(scale.get_value())
        b_pct = ["0%", "33%", "66%", "100%"][self.current_brightness]
        self.bright_val_lbl.set_markup(f"<span color='#FFFFFF'><b>{b_pct}</b></span>")
        self.visualizer.update_state(
            self.current_mode,
            self.current_r,
            self.current_g,
            self.current_b,
            self.current_speed,
            self.current_brightness
        )
        if self.auto_apply:
            self.backend.set_brightness(self.current_brightness)
            self._set_status(f"Brightness set to {b_pct}")

    def _on_power_state_toggle(self):
        awake = 1 if self.sw_awake.get_last_child().get_active() else 0
        sleep = 1 if self.sw_sleep.get_last_child().get_active() else 0
        boot = 1 if self.sw_boot.get_last_child().get_active() else 0
        self.backend.set_power_states(boot, awake, sleep, persist=1)
        self._set_status("Updated power states to hardware firmware")

    def _apply_mode(self):
        ok = self.backend.set_mode(
            self.current_mode,
            self.current_r,
            self.current_g,
            self.current_b,
            self.current_speed
        )
        if ok:
            name = MODES.get(self.current_mode, "Static")
            hex_str = f"#{self.current_r:02X}{self.current_g:02X}{self.current_b:02X}"
            self._set_status(f"Applied '{name}' ({hex_str}) to ASUS TUF A15")
        else:
            self._set_status("Failed to apply mode to sysfs", error=True)

    def _apply_all(self):
        self.backend.set_brightness(self.current_brightness)
        self._apply_mode()
        self._on_power_state_toggle()
        self._set_status("All lighting settings successfully synchronized to ASUS TUF A15!")

    def _reset_defaults(self):
        r, g, b = hex_to_rgb(self.primary_hex)
        self.current_mode = 0
        self.current_r = r
        self.current_g = g
        self.current_b = b
        self.current_speed = 1
        self.current_brightness = 3
        self.sw_awake.get_last_child().set_active(True)
        self.sw_sleep.get_last_child().set_active(False)
        self.sw_boot.get_last_child().set_active(True)
        self._update_accent_theme(self.primary_hex)
        self._sync_to_ui()
        self._apply_all()
        self._set_status(f"Restored Material You default profile ({self.primary_hex.upper()}, 100% brightness)")

    def _set_status(self, msg: str, error: bool = False):
        color = "#FF5252" if error else "#8E96A6"
        self.status_lbl.set_markup(f"<span size='small' color='{color}'>{msg}</span>")


def main():
    app = ArmouryCrateApp()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
