#!/usr/bin/env python3
import os
import sys
import subprocess
import signal
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

PID_FILE = "/tmp/waybar_battery_popup.pid"

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

# Single-instance toggle check
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


def get_battery_details():
    try:
        dev_out = subprocess.check_output(["upower", "-e"], text=True, stderr=subprocess.DEVNULL).strip()
        bat_dev = next((line for line in dev_out.splitlines() if "BAT" in line or "battery" in line), None)
        if not bat_dev:
            return None

        info_out = subprocess.check_output(["upower", "-i", bat_dev], text=True, stderr=subprocess.DEVNULL)
        info = {}
        for line in info_out.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                info[key.strip()] = val.strip()

        pct_str = info.get("percentage", "100%").replace("%", "").strip()
        try:
            pct_val = int(float(pct_str))
        except ValueError:
            pct_val = 100

        state = info.get("state", "discharging").capitalize()
        health = info.get("capacity", "100%")
        rate = info.get("energy-rate", "0 W")
        time_to_empty = info.get("time to empty", "")
        time_to_full = info.get("time to full", "")
        energy = info.get("energy", "N/A")
        energy_full = info.get("energy-full", "N/A")

        is_charging = state.lower() in ["charging", "fully-charged"]

        if is_charging:
            icon = "󰂄"
            subtext = f"Charging ({time_to_full})" if time_to_full else "Charging"
        else:
            if pct_val <= 15:
                icon = "󰁺"
            elif pct_val <= 30:
                icon = "󰁻"
            elif pct_val <= 60:
                icon = "󰁾"
            else:
                icon = "󰁹"
            subtext = f"{time_to_empty} remaining" if time_to_empty else "On Battery Power"

        return {
            "percentage": pct_val,
            "icon": icon,
            "state": state,
            "subtext": subtext,
            "health": health,
            "rate": rate,
            "energy": f"{energy} / {energy_full}",
        }
    except Exception:
        return None


class BatteryPopupWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="BatteryDetails")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 12)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.set_default_size(320, -1)
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
            font-size: 13.5px;
            font-weight: 700;
        }
        .header-icon {
            color: @theme_primary;
            font-size: 15px;
        }
        button {
            background-image: none;
            background-color: transparent;
            box-shadow: none;
            text-shadow: none;
            outline: none;
            border: none;
            padding: 0;
            margin: 0;
        }
        button:hover, button:active, button:focus {
            background-image: none;
            box-shadow: none;
            outline: none;
        }
        .action-icon-btn {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.08);
            color: @theme_on_surface;
            border-radius: 10px;
            min-width: 32px;
            min-height: 32px;
            padding: 0;
            transition: all 0.15s ease;
        }
        .action-icon-btn label {
            font-size: 13.5px;
            margin-right: 2px;
            padding: 0;
        }
        .close-btn:hover {
            background-color: rgba(255, 107, 107, 0.2);
            border-color: @theme_error;
            color: @theme_error;
        }
        .header-icon {
            color: @theme_primary;
            font-size: 15px;
            margin-right: 2px;
        }
        .hero-card {
            background-color: @theme_primary_container;
            border: 1px solid @theme_primary;
            border-radius: 14px;
            padding: 12px 14px;
        }
        .hero-pct {
            color: @theme_primary;
            font-size: 28px;
            font-weight: 800;
        }
        .hero-icon {
            color: @theme_primary;
            font-size: 30px;
            margin-right: 4px;
        }
        .hero-sub {
            color: @theme_on_surface;
            font-size: 11px;
            font-weight: 600;
        }
        progressbar progress {
            background-color: @theme_primary;
            border-radius: 4px;
        }
        progressbar trough {
            background-color: @theme_surface_variant;
            border-radius: 4px;
            min-height: 8px;
        }
        .metric-card {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            padding: 8px 12px;
        }
        .metric-label {
            color: @theme_on_surface_variant;
            font-size: 10.5px;
            font-weight: 600;
        }
        .metric-value {
            color: @theme_on_surface;
            font-size: 11px;
            font-weight: 700;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.set_border_width(12)
        self.add(main_box)

        # 1. Header
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        main_box.pack_start(header_box, False, False, 0)

        icon_label = Gtk.Label(label="󰂄")
        icon_label.get_style_context().add_class("header-icon")
        icon_label.set_xalign(0.5)
        icon_label.set_yalign(0.5)
        header_box.pack_start(icon_label, False, False, 0)

        title = Gtk.Label(label="Battery Status")
        title.get_style_context().add_class("header-title")
        header_box.pack_start(title, False, False, 0)

        header_box.pack_start(Gtk.Box(), True, True, 0)

        close_btn = Gtk.Button()
        close_btn.get_style_context().add_class("action-icon-btn")
        close_btn.get_style_context().add_class("close-btn")
        c_lbl = Gtk.Label(label="")
        c_lbl.set_xalign(0.5)
        c_lbl.set_yalign(0.5)
        c_lbl.set_halign(Gtk.Align.CENTER)
        c_lbl.set_valign(Gtk.Align.CENTER)
        close_btn.add(c_lbl)
        close_btn.set_tooltip_text("Close (Esc)")
        close_btn.connect("clicked", lambda b: self.close_app())
        header_box.pack_start(close_btn, False, False, 0)

        # 2. Hero Card
        bat = get_battery_details()
        if not bat:
            bat = {
                "percentage": 100,
                "icon": "󰁹",
                "state": "Full",
                "subtext": "Power Supply Connected",
                "health": "100%",
                "rate": "0 W",
                "energy": "Full",
            }

        hero_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        hero_card.get_style_context().add_class("hero-card")
        main_box.pack_start(hero_card, False, False, 0)

        top_hero = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hero_card.pack_start(top_hero, False, False, 0)

        h_icon = Gtk.Label(label=bat["icon"])
        h_icon.get_style_context().add_class("hero-icon")
        h_icon.set_xalign(0.5)
        h_icon.set_yalign(0.5)
        top_hero.pack_start(h_icon, False, False, 0)

        hero_text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        h_pct = Gtk.Label(label=f"{bat['percentage']}%")
        h_pct.get_style_context().add_class("hero-pct")
        h_pct.set_halign(Gtk.Align.START)
        hero_text.pack_start(h_pct, False, False, 0)

        h_sub = Gtk.Label(label=bat["subtext"])
        h_sub.get_style_context().add_class("hero-sub")
        h_sub.set_halign(Gtk.Align.START)
        hero_text.pack_start(h_sub, False, False, 0)

        top_hero.pack_start(hero_text, True, True, 0)

        # Progress bar
        bar = Gtk.ProgressBar()
        bar.set_fraction(bat["percentage"] / 100.0)
        hero_card.pack_start(bar, False, False, 0)

        # 3. Metrics Card
        metrics_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        metrics_box.get_style_context().add_class("metric-card")
        main_box.pack_start(metrics_box, False, False, 0)

        metrics = [
            ("State", bat["state"]),
            ("Health (Capacity)", bat["health"]),
            ("Power Draw", bat["rate"]),
            ("Energy Stored", bat["energy"]),
        ]

        for label_text, val_text in metrics:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            lbl = Gtk.Label(label=label_text)
            lbl.get_style_context().add_class("metric-label")
            lbl.set_halign(Gtk.Align.START)
            row.pack_start(lbl, False, False, 0)

            row.pack_start(Gtk.Box(), True, True, 0)

            val = Gtk.Label(label=val_text)
            val.get_style_context().add_class("metric-value")
            val.set_halign(Gtk.Align.END)
            row.pack_start(val, False, False, 0)

            metrics_box.pack_start(row, False, False, 0)

        # Events
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", lambda w: self.cleanup())

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

    win = BatteryPopupWindow()
    win.show_all()
    Gtk.main()
