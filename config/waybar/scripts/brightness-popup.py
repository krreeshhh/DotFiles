#!/usr/bin/env python3
import os
import sys
import subprocess
import signal
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

PID_FILE = "/tmp/waybar_brightness_popup.pid"

# Close conflicting quick panels
for conflict in ["/tmp/waybar_quick_settings.pid", "/tmp/waybar_wifi_menu.pid", "/tmp/waybar_bt_menu.pid"]:
    if os.path.exists(conflict):
        try:
            with open(conflict, "r") as f:
                c_pid = int(f.read().strip())
            os.kill(c_pid, signal.SIGTERM)
        except Exception:
            pass
        try:
            os.remove(conflict)
        except OSError:
            pass

if os.path.exists(PID_FILE):
    try:
        import time
        if time.time() - os.path.getmtime(PID_FILE) < 0.35:
            sys.exit(0)
        with open(PID_FILE, "r") as f:
            old_pid = int(f.read().strip())
        os.kill(old_pid, signal.SIGTERM)
    except Exception:
        pass
    try:
        os.remove(PID_FILE)
    except OSError:
        pass
    sys.exit(0)

with open(PID_FILE, "w") as f:
    f.write(str(os.getpid()))


def get_brightness():
    try:
        b = int(subprocess.check_output(["brightnessctl", "g"], text=True, stderr=subprocess.DEVNULL).strip())
        m = int(subprocess.check_output(["brightnessctl", "m"], text=True, stderr=subprocess.DEVNULL).strip())
        if m > 0:
            return int((b / m) * 100)
    except Exception:
        pass
    return 50

def set_brightness(val):
    try:
        subprocess.run(["brightnessctl", "set", f"{int(val)}%"], stderr=subprocess.DEVNULL)
    except Exception:
        pass


class BrightnessPopup(Gtk.Window):
    def __init__(self):
        super().__init__(title="Brightness")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 12)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.set_default_size(300, -1)
        self.set_decorated(False)
        self.set_resizable(False)

        css_provider = Gtk.CssProvider()
        css = b"""
        @import url("/home/Krish/.config/my-desktop/theme/colors.css");

        window {
            background-color: @theme_bg;
            border: 1px solid @theme_border;
            border-radius: 18px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
        }
        * {
            font-family: 'JetBrainsMono Nerd Font', 'JetBrainsMono NF', monospace;
            outline: none;
        }
        .header-title {
            color: @theme_on_surface;
            font-size: 13px;
            font-weight: 700;
        }
        .header-icon {
            color: @theme_primary;
            font-size: 15px;
            margin-right: 2px;
        }
        .card {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            padding: 8px 12px;
        }
        .pct-label {
            color: @theme_on_surface;
            font-size: 12px;
            font-weight: 700;
        }
        scale highlight {
            background-color: @theme_primary;
            border-radius: 4px;
        }
        scale trough {
            background-color: @theme_surface_variant;
            border-radius: 4px;
            min-height: 8px;
        }
        scale slider {
            min-height: 16px;
            min-width: 16px;
            margin: -4px;
            border-radius: 50%;
            background-color: #ffffff;
            box-shadow: 0 1px 4px rgba(0, 0, 0, 0.4);
        }
        scale slider:hover {
            background-color: @theme_primary;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        main_box.set_border_width(12)
        self.add(main_box)

        cur_val = get_brightness()

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.get_style_context().add_class("card")
        main_box.pack_start(card, True, True, 0)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        card.pack_start(header, False, False, 0)

        icon_lbl = Gtk.Label(label="󰃠")
        icon_lbl.get_style_context().add_class("header-icon")
        icon_lbl.set_xalign(0.5)
        icon_lbl.set_yalign(0.5)
        header.pack_start(icon_lbl, False, False, 0)

        title = Gtk.Label(label="Brightness")
        title.get_style_context().add_class("header-title")
        header.pack_start(title, False, False, 0)

        header.pack_start(Gtk.Box(), True, True, 0)

        self.pct_lbl = Gtk.Label(label=f"{cur_val}%")
        self.pct_lbl.get_style_context().add_class("pct-label")
        header.pack_start(self.pct_lbl, False, False, 0)

        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.scale.set_value(cur_val)
        self.scale.set_draw_value(False)
        self.scale.connect("value-changed", self.on_change)
        card.pack_start(self.scale, False, False, 0)

        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", lambda w: self.cleanup())

    def on_change(self, scale):
        val = int(scale.get_value())
        self.pct_lbl.set_text(f"{val}%")
        set_brightness(val)

    def on_key_press(self, widget, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.close_app()

    def close_app(self):
        self.cleanup()
        Gtk.main_quit()

    def cleanup(self):
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except OSError:
                pass


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))

    win = BrightnessPopup()
    win.show_all()
    Gtk.main()
