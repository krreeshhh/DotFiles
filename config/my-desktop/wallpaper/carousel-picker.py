#!/usr/bin/env python3
"""
3D Card Carousel / Cover Flow Wallpaper Switcher
Designed with GTK Layer Shell and Cairo for Wayland (Hyprland).
Ultra-smooth 144Hz VSync-synchronized animation using GTK Frame Clock.
Zero-latency instant kick-in with asynchronous thumbnail caching and fluid physics.
"""

import os
import sys
import math
import json
import time
import hashlib
import threading
import subprocess
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
gi.require_version('GdkPixbuf', '2.0')

from gi.repository import Gtk, Gdk, GLib, GdkPixbuf, Pango, PangoCairo, GtkLayerShell
import cairo

# Configuration paths
CONFIG_DIR = os.path.expanduser("~/.config/my-desktop")
WALLPAPER_CONFIG = os.path.join(CONFIG_DIR, "wallpaper", "config.env")
CURRENT_WP_FILE = os.path.join(CONFIG_DIR, "wallpaper", "current")
THEME_JSON = os.path.join(CONFIG_DIR, "theme", "colors.json")
APPLY_SCRIPT = os.path.join(CONFIG_DIR, "wallpaper", "apply-wallpaper.sh")
CACHE_DIR_HD = os.path.expanduser("~/.cache/my-desktop/thumbnails_hd")

# Fallback wallpaper directories
DEFAULT_WALLPAPER_DIRS = [
    os.path.expanduser("~/.wallpaper"),
    os.path.expanduser("~/Pictures/Wallpapers"),
    os.path.expanduser("~/Pictures/Walls"),
]

SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

# Animation Timings (in seconds) - Instant kick-in with fluid deceleration
OPEN_DURATION = 0.28      # 280ms instant snappy kick-in with smooth landing
DISMISS_DURATION = 0.20   # 200ms clean smooth fade-out


def ease_out_emphasized(t):
    """High initial velocity for zero input lag, settling into a silky soft landing."""
    t = max(0.0, min(1.0, t))
    return 1.0 - math.pow(1.0 - t, 3.2)


def ease_out_cubic(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


def hex_to_rgb(hex_str, default=(0.97, 0.83, 0.67)):
    if not hex_str:
        return default
    hex_str = hex_str.lstrip('#')
    try:
        if len(hex_str) == 6:
            r = int(hex_str[0:2], 16) / 255.0
            g = int(hex_str[2:4], 16) / 255.0
            b = int(hex_str[4:6], 16) / 255.0
            return (r, g, b)
    except Exception:
        pass
    return default


def load_theme_colors():
    colors = {
        "primary": (0.85, 0.55, 0.68),      # #d88cad
        "on_primary": (0.07, 0.07, 0.08),   # #121214
        "primary_container": (0.24, 0.12, 0.17),
        "secondary": (0.66, 0.67, 0.84),
        "background": (0.07, 0.06, 0.07),   # #130f11
        "surface": (0.12, 0.09, 0.11),      # #1f181b
        "surface_variant": (0.17, 0.13, 0.15),
        "surface_selected": (0.24, 0.12, 0.17),
        "on_surface": (1.0, 1.0, 1.0),
        "on_surface_variant": (0.65, 0.65, 0.67),
        "outline": (0.25, 0.18, 0.21),
        "outline_subtle": (0.15, 0.15, 0.16),
        "error": (1.0, 0.42, 0.42),
    }
    if os.path.isfile(THEME_JSON):
        try:
            with open(THEME_JSON, "r") as f:
                data = json.load(f)
                c = data.get("colors", {})
                for k, v in c.items():
                    if k in colors and isinstance(v, str):
                        colors[k] = hex_to_rgb(v, colors[k])
        except Exception as e:
            sys.stderr.write(f"Error loading theme colors: {e}\n")
    return colors


def get_wallpaper_dir():
    if os.path.isfile(WALLPAPER_CONFIG):
        try:
            with open(WALLPAPER_CONFIG, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("WALLPAPER_DIR="):
                        val = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if ":-" in val:
                            val = val.split(":-", 1)[1].rstrip("}")
                        val = os.path.expandvars(os.path.expanduser(val))
                        if os.path.isdir(val):
                            return val
        except Exception:
            pass

    for d in DEFAULT_WALLPAPER_DIRS:
        if os.path.isdir(d):
            return d
    return os.path.expanduser("~")


def get_current_wallpaper():
    if os.path.isfile(CURRENT_WP_FILE):
        try:
            with open(CURRENT_WP_FILE, "r") as f:
                path = f.read().strip()
                if os.path.isfile(path):
                    return path
        except Exception:
            pass
    return None


class CarouselWallpaperPicker(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)

        # Initialize GTK Layer Shell
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        if hasattr(GtkLayerShell, "set_namespace"):
            GtkLayerShell.set_namespace(self, "quickshell")
        if hasattr(GtkLayerShell, "KeyboardMode"):
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        else:
            GtkLayerShell.set_keyboard_interactivity(self, True)
        GtkLayerShell.set_exclusive_zone(self, -1)

        # Fullscreen anchors
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)

        # RGBA visual for transparency
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        # Theme
        self.theme = load_theme_colors()

        # Wallpapers list
        self.wallpaper_dir = get_wallpaper_dir()
        self.wallpapers = self.scan_wallpapers()
        if not self.wallpapers:
            sys.stderr.write("No wallpapers found!\n")
            sys.exit(1)

        # Find current active wallpaper index
        current_wp = get_current_wallpaper()
        self.current_idx = 0
        if current_wp:
            current_abs = os.path.abspath(current_wp)
            for idx, wp in enumerate(self.wallpapers):
                if os.path.abspath(wp) == current_abs:
                    self.current_idx = idx
                    break

        # Physics & Animation State (Continuous smooth interpolation)
        self.scroll_pos = float(self.current_idx)
        self.target_pos = float(self.current_idx)
        self.tick_id = None
        self.last_frame_time_us = 0
        self.scroll_accumulator = 0.0

        # Window Entrance / Exit State Machine
        self.anim_state = "OPENING"  # "OPENING", "IDLE", "CLOSING_DISMISS"
        self.anim_progress = 0.0

        # Surface cache: {path: (cairo_surface, width, height)}
        self.surface_cache = {}
        self.cache_lock = threading.Lock()

        # Mouse & UI Hitboxes
        self.mouse_x = -1
        self.mouse_y = -1
        self.btn_left_rect = None
        self.btn_right_rect = None
        self.btn_apply_rect = None
        self.card_hitboxes = []

        # Drawing area
        self.draw_area = Gtk.DrawingArea()
        self.draw_area.connect("draw", self.on_draw)
        self.add(self.draw_area)

        # Event handling
        self.draw_area.set_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.SCROLL_MASK
            | Gdk.EventMask.KEY_PRESS_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.connect("key-press-event", self.on_key_press)
        self.connect("scroll-event", self.on_scroll)
        self.draw_area.connect("button-press-event", self.on_button_press)
        self.draw_area.connect("motion-notify-event", self.on_motion_notify)
        self.draw_area.connect("leave-notify-event", self.on_leave_notify)

        # Show window immediately without blocking main thread
        self.show_all()

        # Start 144Hz Frame Clock for Opening Animation
        self.start_animation()

        # Background thread immediately loads active card & preloads rest
        threading.Thread(target=self.async_preload_all, daemon=True).start()

    def scan_wallpapers(self):
        wallpapers = []
        if os.path.isdir(self.wallpaper_dir):
            for root, _, files in os.walk(self.wallpaper_dir):
                for f in sorted(files):
                    ext = os.path.splitext(f)[1].lower()
                    if ext in SUPPORTED_EXTS:
                        wallpapers.append(os.path.join(root, f))
        wallpapers.sort(key=lambda p: os.path.basename(p).lower())
        return wallpapers

    def load_surface_fast(self, path):
        with self.cache_lock:
            if path in self.surface_cache:
                return self.surface_cache[path]

        # Check HD thumbnail cache
        h = hashlib.md5(path.encode('utf-8')).hexdigest()
        thumb_path = os.path.join(CACHE_DIR_HD, f"{h}.jpg")

        load_path = thumb_path if os.path.isfile(thumb_path) else path

        try:
            if load_path == thumb_path:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(thumb_path)
            else:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 720, 450, True)

            w = pixbuf.get_width()
            h_dim = pixbuf.get_height()
            surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h_dim)
            ctx = cairo.Context(surface)
            Gdk.cairo_set_source_pixbuf(ctx, pixbuf, 0, 0)
            ctx.paint()
            with self.cache_lock:
                self.surface_cache[path] = (surface, w, h_dim)
            return (surface, w, h_dim)
        except Exception as e:
            sys.stderr.write(f"Failed to load image {path}: {e}\n")
            return None

    def async_preload_all(self):
        count = len(self.wallpapers)
        # Load active center wallpaper first
        self.load_surface_fast(self.wallpapers[self.current_idx])
        GLib.idle_add(self.draw_area.queue_draw)

        # Preload adjacent cards in order of proximity
        indices = []
        for offset in range(1, count // 2 + 1):
            indices.append((self.current_idx + offset) % count)
            indices.append((self.current_idx - offset) % count)

        for idx in indices:
            path = self.wallpapers[idx]
            with self.cache_lock:
                already_loaded = path in self.surface_cache
            if not already_loaded:
                self.load_surface_fast(path)
                dist = self.get_modular_distance(idx, self.scroll_pos, count)
                if abs(dist) <= 4.0:
                    GLib.idle_add(self.draw_area.queue_draw)

    @staticmethod
    def get_modular_distance(i, pos, count):
        """Returns continuous signed distance between index i and pos with infinite wrapping."""
        return ((i - pos + count / 2.0) % count) - count / 2.0

    def start_animation(self):
        """Starts frame-clock synchronized animation loop at monitor's native refresh rate (e.g. 144Hz)."""
        if self.tick_id is None:
            self.last_frame_time_us = 0
            self.tick_id = self.draw_area.add_tick_callback(self.on_frame_tick)

    def on_frame_tick(self, widget, frame_clock):
        now_us = frame_clock.get_frame_time()
        if self.last_frame_time_us == 0:
            dt = 0.016
        else:
            dt = (now_us - self.last_frame_time_us) / 1000000.0
            # Clamp dt against hiccups / pauses
            dt = max(0.001, min(0.05, dt))
        self.last_frame_time_us = now_us

        needs_redraw = False

        # 1. Opening & Closing Animation Transitions
        if self.anim_state == "OPENING":
            self.anim_progress += dt / OPEN_DURATION
            if self.anim_progress >= 1.0:
                self.anim_progress = 1.0
                self.anim_state = "IDLE"
            needs_redraw = True

        elif self.anim_state == "CLOSING_DISMISS":
            self.anim_progress -= dt / DISMISS_DURATION
            if self.anim_progress <= 0.0:
                self.anim_progress = 0.0
                self.destroy()
                Gtk.main_quit()
                return GLib.SOURCE_REMOVE
            needs_redraw = True

        # 2. Carousel Scroll Physics (Active during OPENING and IDLE)
        if self.anim_state in ("OPENING", "IDLE"):
            diff = self.target_pos - self.scroll_pos
            if abs(diff) > 0.0003:
                # Critically damped exponential decay physics (decay rate = 15.5)
                factor = 1.0 - math.exp(-15.5 * dt)
                self.scroll_pos += diff * factor
                needs_redraw = True
            else:
                count = len(self.wallpapers)
                self.scroll_pos = (self.target_pos % count + count) % count
                self.target_pos = self.scroll_pos

        if needs_redraw:
            widget.queue_draw()
            return GLib.SOURCE_CONTINUE
        else:
            self.tick_id = None
            return GLib.SOURCE_REMOVE

    def select_offset(self, delta):
        if self.anim_state == "CLOSING_DISMISS":
            return
        self.target_pos = round(self.target_pos) + delta
        self.start_animation()

    def jump_to_index(self, target_idx):
        if self.anim_state == "CLOSING_DISMISS":
            return
        count = len(self.wallpapers)
        target_idx = target_idx % count
        curr_normalized = (self.scroll_pos % count + count) % count
        delta = self.get_modular_distance(target_idx, curr_normalized, count)
        self.target_pos = self.scroll_pos + delta
        self.start_animation()

    def on_key_press(self, widget, event):
        if self.anim_state == "CLOSING_DISMISS":
            return True

        key = event.keyval
        if key in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_Q):
            self.close_picker()
            return True
        elif key in (Gdk.KEY_Left, Gdk.KEY_h, Gdk.KEY_H, Gdk.KEY_Up, Gdk.KEY_k, Gdk.KEY_K):
            self.select_offset(-1)
            return True
        elif key in (Gdk.KEY_Right, Gdk.KEY_l, Gdk.KEY_L, Gdk.KEY_Down, Gdk.KEY_j, Gdk.KEY_J):
            self.select_offset(1)
            return True
        elif key in (Gdk.KEY_Page_Up,):
            self.select_offset(-3)
            return True
        elif key in (Gdk.KEY_Page_Down,):
            self.select_offset(3)
            return True
        elif key in (Gdk.KEY_Home,):
            self.jump_to_index(0)
            return True
        elif key in (Gdk.KEY_End,):
            self.jump_to_index(len(self.wallpapers) - 1)
            return True
        elif key in (Gdk.KEY_Return, Gdk.KEY_KP_Enter, Gdk.KEY_space):
            self.apply_current_selection()
            return True
        return False

    def on_scroll(self, widget, event):
        if self.anim_state == "CLOSING_DISMISS":
            return True

        delta = 0
        if event.direction == Gdk.ScrollDirection.UP:
            delta = -1
        elif event.direction == Gdk.ScrollDirection.DOWN:
            delta = 1
        elif event.direction == Gdk.ScrollDirection.LEFT:
            delta = -1
        elif event.direction == Gdk.ScrollDirection.RIGHT:
            delta = 1
        elif event.direction == Gdk.ScrollDirection.SMOOTH:
            self.scroll_accumulator += event.delta_y if abs(event.delta_y) > abs(event.delta_x) else event.delta_x
            if self.scroll_accumulator >= 0.5:
                delta = 1
                self.scroll_accumulator = 0.0
            elif self.scroll_accumulator <= -0.5:
                delta = -1
                self.scroll_accumulator = 0.0

        if delta != 0:
            self.select_offset(delta)
            return True
        return False

    def on_motion_notify(self, widget, event):
        self.mouse_x = event.x
        self.mouse_y = event.y
        if self.anim_state in ("OPENING", "IDLE"):
            self.draw_area.queue_draw()
        return False

    def on_leave_notify(self, widget, event):
        self.mouse_x = -1
        self.mouse_y = -1
        if self.anim_state in ("OPENING", "IDLE"):
            self.draw_area.queue_draw()
        return False

    def on_button_press(self, widget, event):
        if self.anim_state == "CLOSING_DISMISS":
            return True

        if event.button != 1:
            return False

        ex, ey = event.x, event.y

        # 1. Left Arrow Button
        if self.btn_left_rect:
            bx, by, bw, bh = self.btn_left_rect
            if bx <= ex <= bx + bw and by <= ey <= by + bh:
                self.select_offset(-1)
                return True

        # 2. Right Arrow Button
        if self.btn_right_rect:
            bx, by, bw, bh = self.btn_right_rect
            if bx <= ex <= bx + bw and by <= ey <= by + bh:
                self.select_offset(1)
                return True

        # 3. Apply Pill Button
        if self.btn_apply_rect:
            bx, by, bw, bh = self.btn_apply_rect
            if bx <= ex <= bx + bw and by <= ey <= by + bh:
                self.apply_current_selection()
                return True

        # 4. Visible Cards (front to back)
        for card in self.card_hitboxes:
            cx, cy, cw, ch, idx, dist = card
            if (cx - cw / 2.0) <= ex <= (cx + cw / 2.0) and (cy - ch / 2.0) <= ey <= (cy + ch / 2.0):
                if dist < 0.35:
                    self.apply_current_selection()
                else:
                    self.jump_to_index(idx)
                return True

        # 5. Clicked Outside on Backdrop: Close Picker
        self.close_picker()
        return True

    def apply_current_selection(self):
        if self.anim_state == "CLOSING_DISMISS":
            return

        count = len(self.wallpapers)
        active_idx = int(round(self.scroll_pos)) % count
        selected_wp = self.wallpapers[active_idx]

        # Launch wallpaper change in background
        if os.path.isfile(APPLY_SCRIPT):
            subprocess.Popen(["bash", APPLY_SCRIPT, selected_wp])
        else:
            sys.stderr.write(f"Apply script not found: {APPLY_SCRIPT}\n")

        # Smoothly fade out the picker window
        self.close_picker()

    def close_picker(self):
        if self.anim_state == "CLOSING_DISMISS":
            return
        self.anim_state = "CLOSING_DISMISS"
        self.start_animation()

    def draw_rounded_rect(self, ctx, x, y, width, height, radius):
        degrees = math.pi / 180.0
        radius = max(0.0, min(radius, min(width, height) / 2.0))
        if radius <= 0.0:
            ctx.rectangle(x, y, width, height)
            return
        ctx.new_sub_path()
        ctx.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees)
        ctx.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees)
        ctx.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees)
        ctx.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees)
        ctx.close_path()

    def on_draw(self, widget, ctx):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        count = len(self.wallpapers)
        if count == 0:
            return False

        bg_r, bg_g, bg_b = self.theme["background"]
        surf_r, surf_g, surf_b = self.theme["surface"]
        pr, pg, pb = self.theme["primary"]
        sec_r, sec_g, sec_b = self.theme["secondary"]
        out_r, out_g, out_b = self.theme["outline"]
        fg_r, fg_g, fg_b = self.theme["on_surface"]
        fg_var_r, fg_var_g, fg_var_b = self.theme["on_surface_variant"]

        # Calculate animation variables based on current state
        if self.anim_state == "OPENING":
            t_open = ease_out_emphasized(self.anim_progress)
            backdrop_alpha = 0.65 * ease_out_cubic(self.anim_progress)
            carousel_scale = 0.88 + 0.12 * t_open
            carousel_offset_y = (1.0 - t_open) * 26.0
            carousel_alpha = ease_out_cubic(self.anim_progress)

            # UI text and pill cascade smoothly without delay
            title_stagger = max(0.0, min(1.0, (self.anim_progress - 0.04) / 0.96))
            title_alpha = ease_out_emphasized(title_stagger)
            title_offset_y = (1.0 - title_alpha) * 16.0

            pill_stagger = max(0.0, min(1.0, (self.anim_progress - 0.08) / 0.92))
            pill_alpha = ease_out_emphasized(pill_stagger)
            pill_offset_y = (1.0 - pill_alpha) * 16.0

        elif self.anim_state == "CLOSING_DISMISS":
            t_dismiss = ease_out_emphasized(self.anim_progress)
            backdrop_alpha = 0.65 * self.anim_progress
            carousel_scale = 0.93 + 0.07 * t_dismiss
            carousel_offset_y = (1.0 - t_dismiss) * 18.0
            carousel_alpha = self.anim_progress

            title_alpha = self.anim_progress
            title_offset_y = (1.0 - t_dismiss) * 12.0
            pill_alpha = self.anim_progress
            pill_offset_y = (1.0 - t_dismiss) * 12.0

        else:  # IDLE
            backdrop_alpha = 0.65
            carousel_scale = 1.0
            carousel_offset_y = 0.0
            carousel_alpha = 1.0
            title_alpha = 1.0
            title_offset_y = 0.0
            pill_alpha = 1.0
            pill_offset_y = 0.0

        # 1. Quickshell-matching Translucent Glass Backdrop
        if backdrop_alpha > 0.001:
            ctx.set_source_rgba(bg_r, bg_g, bg_b, backdrop_alpha)
            ctx.paint()

        center_x = w / 2.0
        center_y = h / 2.0 - 45.0 + carousel_offset_y

        # Responsive card sizing
        card_w = min(640.0, w * 0.44) * carousel_scale
        card_h = card_w * 0.585
        base_radius = 16.0 * carousel_scale

        # Cover Flow Spacing
        slot_step_near = card_w * 0.45
        slot_step_far = card_w * 0.25

        # Build list of cards within visible range
        cards_to_draw = []
        for i in range(count):
            signed_dist = self.get_modular_distance(i, self.scroll_pos, count)
            dist = abs(signed_dist)
            if dist > 4.2:
                continue

            scale = 1.0 / (1.0 + 0.165 * dist)
            cw = card_w * scale
            ch = card_h * scale

            if dist == 0:
                cx = center_x
            else:
                sign = 1.0 if signed_dist > 0 else -1.0
                if dist <= 1.0:
                    delta_x = sign * (slot_step_near * dist)
                else:
                    delta_x = sign * (slot_step_near + slot_step_far * (dist - 1.0))
                cx = center_x + delta_x

            cy = center_y + (1.0 - scale) * 20.0

            card_alpha = carousel_alpha
            radius = base_radius * scale
            border_alpha = max(0.0, 1.0 - (dist / 0.8)) if dist < 0.8 else 0.40

            if card_alpha <= 0.001:
                continue

            cards_to_draw.append({
                "idx": i,
                "path": self.wallpapers[i],
                "cx": cx,
                "cy": cy,
                "cw": cw,
                "ch": ch,
                "scale": scale,
                "dist": dist,
                "radius": radius,
                "card_alpha": card_alpha,
                "border_alpha": border_alpha,
            })

        # Render from back (largest dist) to front (dist = 0)
        cards_to_draw.sort(key=lambda item: item["dist"], reverse=True)

        # Record hitboxes in front-to-back order for mouse selection (only when interactive)
        if self.anim_state in ("OPENING", "IDLE"):
            self.card_hitboxes = [
                (c["cx"], c["cy"], c["cw"], c["ch"], c["idx"], c["dist"])
                for c in sorted(cards_to_draw, key=lambda item: item["dist"])
            ]
        else:
            self.card_hitboxes = []

        for c in cards_to_draw:
            cx, cy, cw, ch = c["cx"], c["cy"], c["cw"], c["ch"]
            radius = c["radius"]
            dist = c["dist"]
            path = c["path"]
            c_alpha = c["card_alpha"]
            b_alpha = c["border_alpha"]

            # Drop Shadow for front cards
            if dist < 1.6 and c_alpha > 0.01:
                shadow_alpha = max(0.0, (1.6 - dist) / 1.6) * 0.50 * c_alpha
                if shadow_alpha > 0.005:
                    ctx.save()
                    self.draw_rounded_rect(ctx, cx - cw / 2.0 - 5, cy - ch / 2.0 + 7, cw + 10, ch + 10, radius + 5)
                    ctx.set_source_rgba(0.0, 0.0, 0.0, shadow_alpha)
                    ctx.fill()
                    ctx.restore()

            # Retrieve surface from cache
            with self.cache_lock:
                cached = self.surface_cache.get(path)

            ctx.save()
            self.draw_rounded_rect(ctx, cx - cw / 2.0, cy - ch / 2.0, cw, ch, radius)
            ctx.clip()

            if cached:
                surface, sw, sh = cached
                ctx.save()
                scale_img_x = cw / sw
                scale_img_y = ch / sh
                img_scale = max(scale_img_x, scale_img_y)
                draw_w = sw * img_scale
                draw_h = sh * img_scale
                img_x = cx - draw_w / 2.0
                img_y = cy - draw_h / 2.0

                ctx.translate(img_x, img_y)
                ctx.scale(img_scale, img_scale)
                ctx.set_source_surface(surface, 0, 0)
                pattern = ctx.get_source()
                pattern.set_filter(cairo.FILTER_BILINEAR)
                if c_alpha < 0.999:
                    ctx.paint_with_alpha(c_alpha)
                else:
                    ctx.paint()
                ctx.restore()
            else:
                ctx.set_source_rgba(surf_r, surf_g, surf_b, c_alpha)
                ctx.paint()

            # Dimming / darkness overlay on background cards
            if dist > 0.04 and c_alpha > 0.01:
                dark_alpha = min(0.70, dist * 0.22 + 0.12) * c_alpha
                ctx.set_source_rgba(bg_r * 0.5, bg_g * 0.5, bg_b * 0.5, dark_alpha)
                ctx.paint()

            ctx.restore()

            # Border
            if b_alpha > 0.01 and c_alpha > 0.01:
                ctx.save()
                if dist < 0.8:
                    border_width = 2.8 * carousel_scale
                    self.draw_rounded_rect(ctx, cx - cw / 2.0, cy - ch / 2.0, cw, ch, radius)
                    ctx.set_source_rgba(pr, pg, pb, b_alpha * 0.95 * c_alpha)
                    ctx.set_line_width(border_width)
                    ctx.stroke()
                else:
                    self.draw_rounded_rect(ctx, cx - cw / 2.0, cy - ch / 2.0, cw, ch, radius)
                    ctx.set_source_rgba(out_r, out_g, out_b, 0.40 * c_alpha)
                    ctx.set_line_width(1.0)
                    ctx.stroke()
                ctx.restore()

        # 2. Wallpaper Title
        if title_alpha > 0.01:
            active_idx = int(round(self.scroll_pos)) % count
            active_path = self.wallpapers[active_idx]
            raw_name = os.path.splitext(os.path.basename(active_path))[0]
            display_name = raw_name.replace("_", " ").replace("-", " ")

            title_y = center_y + card_h / 2.0 + 38.0 + title_offset_y

            pango_ctx = self.get_pango_context()
            layout = Pango.Layout(pango_ctx)
            font_desc = Pango.FontDescription("JetBrainsMono Nerd Font Bold 16")
            layout.set_font_description(font_desc)
            layout.set_text(display_name, -1)

            _, t_log = layout.get_pixel_extents()
            title_w = t_log.width
            title_h = t_log.height

            # Title shadow
            ctx.save()
            ctx.set_source_rgba(0.0, 0.0, 0.0, 0.6 * title_alpha)
            ctx.move_to(center_x - title_w / 2.0 + 1.5, title_y + 1.5)
            PangoCairo.show_layout(ctx, layout)
            ctx.restore()

            # Title text
            ctx.save()
            ctx.set_source_rgba(fg_r, fg_g, fg_b, title_alpha)
            ctx.move_to(center_x - title_w / 2.0, title_y)
            PangoCairo.show_layout(ctx, layout)
            ctx.restore()

        # 3. Bottom Pill Navigation Bar
        if pill_alpha > 0.01:
            active_idx = int(round(self.scroll_pos)) % count
            pill_y = (center_y + card_h / 2.0 + 38.0) + 36.0 + 24.0 + pill_offset_y
            pill_w = 360.0
            pill_h = 32.0
            pill_x = center_x - pill_w / 2.0
            pill_radius = pill_h / 2.0

            # Pill background matching Quickshell popup card
            ctx.save()
            self.draw_rounded_rect(ctx, pill_x, pill_y, pill_w, pill_h, pill_radius)
            ctx.set_source_rgba(surf_r, surf_g, surf_b, 0.75 * pill_alpha)
            ctx.fill_preserve()
            ctx.set_source_rgba(out_r, out_g, out_b, 0.50 * pill_alpha)
            ctx.set_line_width(1.0)
            ctx.stroke()
            ctx.restore()

            arrow_w = 34.0
            self.btn_left_rect = (pill_x + 3.0, pill_y + 2.0, arrow_w, pill_h - 4.0)
            self.btn_right_rect = (pill_x + pill_w - arrow_w - 3.0, pill_y + 2.0, arrow_w, pill_h - 4.0)
            self.btn_apply_rect = (pill_x + arrow_w, pill_y + 2.0, pill_w - (2 * arrow_w), pill_h - 4.0)

            # Hover states
            hover_left = (self.btn_left_rect[0] <= self.mouse_x <= self.btn_left_rect[0] + arrow_w and
                          self.btn_left_rect[1] <= self.mouse_y <= self.btn_left_rect[1] + pill_h - 4.0)
            hover_right = (self.btn_right_rect[0] <= self.mouse_x <= self.btn_right_rect[0] + arrow_w and
                           self.btn_right_rect[1] <= self.mouse_y <= self.btn_right_rect[1] + pill_h - 4.0)

            if hover_left and self.anim_state == "IDLE":
                ctx.save()
                self.draw_rounded_rect(ctx, self.btn_left_rect[0], self.btn_left_rect[1], arrow_w, pill_h - 4.0, (pill_h - 4.0) / 2.0)
                ctx.set_source_rgba(pr, pg, pb, 0.20 * pill_alpha)
                ctx.fill()
                ctx.restore()

            if hover_right and self.anim_state == "IDLE":
                ctx.save()
                self.draw_rounded_rect(ctx, self.btn_right_rect[0], self.btn_right_rect[1], arrow_w, pill_h - 4.0, (pill_h - 4.0) / 2.0)
                ctx.set_source_rgba(pr, pg, pb, 0.20 * pill_alpha)
                ctx.fill()
                ctx.restore()

            pango_ctx = self.get_pango_context()

            # Left Arrow
            layout_arrow = Pango.Layout(pango_ctx)
            font_arrow = Pango.FontDescription("JetBrainsMono Nerd Font Bold 10")
            layout_arrow.set_font_description(font_arrow)
            layout_arrow.set_text("󰁍", -1)
            _, la_log = layout_arrow.get_pixel_extents()

            ctx.save()
            ctx.set_source_rgba(pr, pg, pb, (1.0 if hover_left else 0.85) * pill_alpha)
            ctx.move_to(pill_x + 18.0 - la_log.width / 2.0, pill_y + (pill_h - la_log.height) / 2.0)
            PangoCairo.show_layout(ctx, layout_arrow)
            ctx.restore()

            # Right Arrow
            layout_arrow.set_text("󰁔", -1)
            _, ra_log = layout_arrow.get_pixel_extents()

            ctx.save()
            ctx.set_source_rgba(pr, pg, pb, (1.0 if hover_right else 0.85) * pill_alpha)
            ctx.move_to(pill_x + pill_w - 18.0 - ra_log.width / 2.0, pill_y + (pill_h - ra_log.height) / 2.0)
            PangoCairo.show_layout(ctx, layout_arrow)
            ctx.restore()

            # Center Status & Keybind Hint
            layout_pill = Pango.Layout(pango_ctx)
            font_pill = Pango.FontDescription("JetBrainsMono Nerd Font Medium 8.5")
            layout_pill.set_font_description(font_pill)
            pill_text = f"Enter Apply  ·  Esc Close  ·  {active_idx + 1}/{count}"
            layout_pill.set_text(pill_text, -1)
            _, p_log = layout_pill.get_pixel_extents()

            ctx.save()
            ctx.set_source_rgba(fg_var_r, fg_var_g, fg_var_b, 0.90 * pill_alpha)
            ctx.move_to(center_x - p_log.width / 2.0, pill_y + (pill_h - p_log.height) / 2.0)
            PangoCairo.show_layout(ctx, layout_pill)
            ctx.restore()
        else:
            self.btn_left_rect = None
            self.btn_right_rect = None
            self.btn_apply_rect = None

        return False


def main():
    pid_file = "/tmp/carousel-picker.pid"
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                old_pid = int(f.read().strip())
            if old_pid != os.getpid():
                os.kill(old_pid, 9)
        except Exception:
            pass
    try:
        with open(pid_file, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

    app = CarouselWallpaperPicker()
    Gtk.main()


if __name__ == "__main__":
    main()
