#!/usr/bin/env python3
import os
import sys
import subprocess
import signal
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

PID_FILE = "/tmp/waybar_quick_settings.pid"

# Close conflicting quick panels
for conflict in ["/tmp/waybar_wifi_menu.pid", "/tmp/waybar_bt_menu.pid", "/tmp/waybar_battery_popup.pid"]:
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


def get_volume():
    try:
        out = subprocess.check_output(["pamixer", "--get-volume"], text=True, stderr=subprocess.DEVNULL).strip()
        muted = subprocess.check_output(["pamixer", "--get-mute"], text=True, stderr=subprocess.DEVNULL).strip() == "true"
        return int(out), muted
    except Exception:
        pass
    try:
        out = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True, stderr=subprocess.DEVNULL).strip()
        parts = out.split()
        vol = int(float(parts[1]) * 100)
        muted = "[MUTED]" in out
        return vol, muted
    except Exception:
        pass
    return 50, False

def set_volume(val):
    val = max(0, min(100, int(val)))
    try:
        subprocess.run(["pamixer", "--set-volume", str(val)], stderr=subprocess.DEVNULL)
    except Exception:
        try:
            subprocess.run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{val/100:.2f}"], stderr=subprocess.DEVNULL)
        except Exception:
            pass

def toggle_mute():
    try:
        subprocess.run(["pamixer", "-t"], stderr=subprocess.DEVNULL)
    except Exception:
        try:
            subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], stderr=subprocess.DEVNULL)
        except Exception:
            pass

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

def get_wifi_status():
    try:
        radio = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, stderr=subprocess.DEVNULL).strip() == "enabled"
        ssid = "Disconnected"
        if radio:
            out = subprocess.check_output(["nmcli", "-t", "-f", "TYPE,NAME", "connection", "show", "--active"], text=True, stderr=subprocess.DEVNULL)
            for line in out.splitlines():
                if line.startswith("802-11-wireless:"):
                    ssid = line.split(":", 1)[1]
                    break
        return radio, ssid
    except Exception:
        return False, "Unavailable"

def toggle_wifi(enable):
    try:
        state = "on" if enable else "off"
        subprocess.run(["nmcli", "radio", "wifi", state], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def get_bluetooth_status():
    try:
        out = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL)
        powered = "Powered: yes" in out
        dev = "No device"
        if powered:
            devs = subprocess.check_output(["bluetoothctl", "devices", "Connected"], text=True, stderr=subprocess.DEVNULL).strip()
            if devs:
                dev = devs.split("\n")[0].split(" ", 2)[-1]
        return powered, dev
    except Exception:
        return False, "Unavailable"

def toggle_bluetooth(enable):
    try:
        cmd = "power on" if enable else "power off"
        subprocess.run(["bluetoothctl", cmd], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def get_battery_info():
    try:
        import glob
        for path in glob.glob("/sys/class/power_supply/BAT*"):
            with open(os.path.join(path, "capacity")) as f:
                pct = f.read().strip() + "%"
            with open(os.path.join(path, "status")) as f:
                state = f.read().strip()
            icon = "󰂄" if state.lower() in ["charging", "full"] else "󰁹"
            return icon, pct
    except Exception:
        pass
    return "󰁹", "100%"


def make_icon_btn(icon_text, tooltip, callback, extra_class=None):
    btn = Gtk.Button()
    btn.get_style_context().add_class("action-icon-btn")
    if extra_class:
        btn.get_style_context().add_class(extra_class)
    lbl = Gtk.Label(label=icon_text)
    lbl.set_xalign(0.5)
    lbl.set_yalign(0.5)
    lbl.set_halign(Gtk.Align.CENTER)
    lbl.set_valign(Gtk.Align.CENTER)
    btn.add(lbl)
    btn.set_tooltip_text(tooltip)
    if callback:
        btn.connect("clicked", callback)
    return btn


class QuickSettingsWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="QuickSettings")

        # Layer Shell setup
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 12)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.set_default_size(360, -1)
        self.set_decorated(False)
        self.set_resizable(False)

        # Dynamic Material You Theme CSS
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
        button label {
            color: inherit;
        }
        .badge {
            background-color: @theme_surface;
            color: @theme_primary;
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            padding: 2px 10px;
            font-size: 11px;
            font-weight: 700;
            min-height: 28px;
            transition: all 0.15s ease;
        }
        .badge label {
            margin-right: 2px;
        }
        .badge:hover {
            background-color: @theme_surface_selected;
            border-color: @theme_primary;
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
        .action-icon-btn:hover {
            background-color: @theme_surface_selected;
            border-color: @theme_primary;
            color: @theme_primary;
        }
        .close-btn:hover {
            background-color: rgba(255, 107, 107, 0.2);
            border-color: @theme_error;
            color: @theme_error;
        }
        .card {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 14px;
            padding: 8px 12px;
        }
        .slider-icon {
            color: @theme_primary;
            font-size: 15px;
            min-width: 26px;
            margin-right: 3px;
        }
        .slider-pct {
            color: @theme_on_surface;
            font-size: 11.5px;
            font-weight: 600;
            min-width: 38px;
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
        .toggle-tile {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.07);
            border-radius: 14px;
            padding: 0;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .toggle-tile.active {
            background-color: @theme_primary_container;
            border-color: @theme_primary;
        }
        .toggle-main-btn {
            padding: 8px 10px;
            border-radius: 14px 0 0 14px;
        }
        .toggle-main-btn:hover {
            background-color: rgba(255, 255, 255, 0.04);
        }
        .toggle-icon-badge {
            background-color: rgba(255, 255, 255, 0.06);
            color: @theme_on_surface_variant;
            border-radius: 50%;
            min-width: 34px;
            min-height: 34px;
            transition: all 0.2s ease;
        }
        .toggle-tile.active .toggle-icon-badge {
            background-color: @theme_primary;
            color: @theme_on_primary;
        }
        .toggle-badge-icon {
            font-size: 14px;
            margin-right: 3px;
        }
        .toggle-title {
            color: @theme_on_surface;
            font-size: 12px;
            font-weight: 700;
        }
        .toggle-sub {
            color: @theme_on_surface_variant;
            font-size: 10px;
            font-weight: 500;
        }
        .toggle-tile.active .toggle-sub {
            color: @theme_primary;
        }
        .toggle-arrow-btn {
            border-left: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 0 14px 14px 0;
            padding: 0;
            min-width: 32px;
        }
        .toggle-arrow-btn:hover {
            background-color: rgba(255, 255, 255, 0.08);
            color: @theme_primary;
        }
        .arrow-icon {
            font-size: 13px;
            color: @theme_on_surface_variant;
            margin-right: 3px;
        }
        .toggle-arrow-btn:hover .arrow-icon {
            color: @theme_primary;
        }
        .util-btn {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            min-height: 34px;
            padding: 0 8px;
            transition: all 0.15s ease;
        }
        .util-btn label {
            color: @theme_on_surface;
            font-size: 12px;
            margin-right: 1px;
        }
        .util-btn:hover {
            background-color: @theme_surface_selected;
            border-color: @theme_primary;
        }
        .util-btn:hover label {
            color: @theme_primary;
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

        # -------------------------------------------------------------
        # 1. Header Row
        # -------------------------------------------------------------
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        main_box.pack_start(header_box, False, False, 0)

        title_icon = Gtk.Label(label="󰀻")
        title_icon.get_style_context().add_class("slider-icon")
        title_icon.set_xalign(0.5)
        title_icon.set_yalign(0.5)
        header_box.pack_start(title_icon, False, False, 0)

        title = Gtk.Label(label="Quick Settings")
        title.get_style_context().add_class("header-title")
        header_box.pack_start(title, False, False, 0)

        header_box.pack_start(Gtk.Box(), True, True, 0)  # spacer

        # Battery badge
        bat_icon, bat_pct = get_battery_info()
        self.bat_badge = Gtk.Button()
        self.bat_badge.get_style_context().add_class("badge")
        bat_lbl = Gtk.Label(label=f"{bat_icon} {bat_pct}")
        bat_lbl.set_xalign(0.5)
        bat_lbl.set_yalign(0.5)
        bat_lbl.set_halign(Gtk.Align.CENTER)
        bat_lbl.set_valign(Gtk.Align.CENTER)
        self.bat_badge.add(bat_lbl)
        self.bat_badge.set_tooltip_text("Battery Statistics")
        self.bat_badge.connect("clicked", lambda b: subprocess.Popen(["bash", "/home/Krish/.config/waybar/scripts/battery-popup.sh"]))
        header_box.pack_start(self.bat_badge, False, False, 0)

        # Pavucontrol launcher button
        pavu_btn = make_icon_btn("", "Open Audio Mixer", lambda b: subprocess.Popen(["pavucontrol"]))
        header_box.pack_start(pavu_btn, False, False, 0)

        # Area Screenshot button
        shot_btn = make_icon_btn("", "Area Screenshot", self.on_take_screenshot)
        header_box.pack_start(shot_btn, False, False, 0)

        # Close button
        close_btn = make_icon_btn("", "Close (Esc)", lambda b: self.close_app(), "close-btn")
        header_box.pack_start(close_btn, False, False, 0)

        # -------------------------------------------------------------
        # 2. Sliders Section (Card Container)
        # -------------------------------------------------------------
        sliders_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        sliders_card.get_style_context().add_class("card")
        main_box.pack_start(sliders_card, False, False, 0)

        # Volume Slider Row
        vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        sliders_card.pack_start(vol_row, False, False, 0)

        vol_val, is_muted = get_volume()
        self.mute_btn = Gtk.Button()
        self.mute_lbl = Gtk.Label(label="󰝟" if is_muted else self.get_vol_icon(vol_val))
        self.mute_lbl.get_style_context().add_class("slider-icon")
        self.mute_lbl.set_xalign(0.5)
        self.mute_lbl.set_yalign(0.5)
        self.mute_lbl.set_halign(Gtk.Align.CENTER)
        self.mute_lbl.set_valign(Gtk.Align.CENTER)
        self.mute_btn.add(self.mute_lbl)
        self.mute_btn.set_tooltip_text("Click to Mute / Unmute")
        self.mute_btn.connect("clicked", self.on_toggle_mute)
        vol_row.pack_start(self.mute_btn, False, False, 0)

        self.vol_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.vol_scale.set_value(vol_val)
        self.vol_scale.set_draw_value(False)
        self.vol_scale.connect("value-changed", self.on_vol_change)
        vol_row.pack_start(self.vol_scale, True, True, 0)

        self.vol_pct_lbl = Gtk.Label(label="Muted" if is_muted else f"{vol_val}%")
        self.vol_pct_lbl.get_style_context().add_class("slider-pct")
        self.vol_pct_lbl.set_halign(Gtk.Align.END)
        vol_row.pack_start(self.vol_pct_lbl, False, False, 0)

        # Brightness Slider Row
        bright_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        sliders_card.pack_start(bright_row, False, False, 0)

        bright_val = get_brightness()
        bright_icon = Gtk.Label(label="󰃠")
        bright_icon.get_style_context().add_class("slider-icon")
        bright_icon.set_xalign(0.5)
        bright_icon.set_yalign(0.5)
        bright_icon.set_halign(Gtk.Align.CENTER)
        bright_icon.set_valign(Gtk.Align.CENTER)
        bright_row.pack_start(bright_icon, False, False, 0)

        self.bright_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.bright_scale.set_value(bright_val)
        self.bright_scale.set_draw_value(False)
        self.bright_scale.connect("value-changed", self.on_bright_change)
        bright_row.pack_start(self.bright_scale, True, True, 0)

        self.bright_pct_lbl = Gtk.Label(label=f"{bright_val}%")
        self.bright_pct_lbl.get_style_context().add_class("slider-pct")
        self.bright_pct_lbl.set_halign(Gtk.Align.END)
        bright_row.pack_start(self.bright_pct_lbl, False, False, 0)

        # -------------------------------------------------------------
        # 3. Quick Toggles Grid (Wi-Fi & Bluetooth Dual-Pill Cards)
        # -------------------------------------------------------------
        toggles_grid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        main_box.pack_start(toggles_grid, False, False, 0)

        # Wi-Fi Tile
        self.wifi_radio, self.wifi_ssid = get_wifi_status()
        self.wifi_tile = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.wifi_tile.get_style_context().add_class("toggle-tile")
        if self.wifi_radio:
            self.wifi_tile.get_style_context().add_class("active")

        # Wi-Fi Left Button (Toggle On/Off)
        wifi_main = Gtk.Button()
        wifi_main.get_style_context().add_class("toggle-main-btn")
        wifi_main.connect("clicked", self.on_toggle_wifi_clicked)
        wifi_content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        wifi_main.add(wifi_content)

        wifi_icon_box = Gtk.Box()
        wifi_icon_box.get_style_context().add_class("toggle-icon-badge")
        wifi_icon_box.set_halign(Gtk.Align.CENTER)
        wifi_icon_box.set_valign(Gtk.Align.CENTER)

        self.wifi_icon_lbl = Gtk.Label(label="󰤨" if self.wifi_radio else "󰤮")
        self.wifi_icon_lbl.get_style_context().add_class("toggle-badge-icon")
        self.wifi_icon_lbl.set_xalign(0.5)
        self.wifi_icon_lbl.set_yalign(0.5)
        self.wifi_icon_lbl.set_halign(Gtk.Align.CENTER)
        self.wifi_icon_lbl.set_valign(Gtk.Align.CENTER)
        wifi_icon_box.pack_start(self.wifi_icon_lbl, True, True, 0)
        wifi_content.pack_start(wifi_icon_box, False, False, 0)

        wifi_text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        wifi_text_box.set_valign(Gtk.Align.CENTER)
        w_title = Gtk.Label(label="Wi-Fi")
        w_title.get_style_context().add_class("toggle-title")
        w_title.set_halign(Gtk.Align.START)
        wifi_text_box.pack_start(w_title, False, False, 0)

        self.wifi_sub = Gtk.Label(label=self.wifi_ssid if self.wifi_radio else "Disabled")
        self.wifi_sub.get_style_context().add_class("toggle-sub")
        self.wifi_sub.set_halign(Gtk.Align.START)
        self.wifi_sub.set_ellipsize(3)
        self.wifi_sub.set_max_width_chars(11)
        wifi_text_box.pack_start(self.wifi_sub, False, False, 0)
        wifi_content.pack_start(wifi_text_box, True, True, 0)

        self.wifi_tile.pack_start(wifi_main, True, True, 0)

        # Wi-Fi Right Arrow (Open Sub-menu)
        wifi_arrow = Gtk.Button()
        wifi_arrow.get_style_context().add_class("toggle-arrow-btn")
        w_arr_lbl = Gtk.Label(label="󰅂")
        w_arr_lbl.get_style_context().add_class("arrow-icon")
        w_arr_lbl.set_xalign(0.5)
        w_arr_lbl.set_yalign(0.5)
        w_arr_lbl.set_halign(Gtk.Align.CENTER)
        w_arr_lbl.set_valign(Gtk.Align.CENTER)
        wifi_arrow.add(w_arr_lbl)
        wifi_arrow.set_tooltip_text("Open Wi-Fi Networks Dropdown")
        wifi_arrow.connect("clicked", lambda b: subprocess.Popen(["python3", "/home/Krish/.config/waybar/scripts/wifi-menu.py"]))
        self.wifi_tile.pack_start(wifi_arrow, False, False, 0)

        toggles_grid.pack_start(self.wifi_tile, True, True, 0)

        # Bluetooth Tile
        self.bt_power, self.bt_dev = get_bluetooth_status()
        self.bt_tile = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.bt_tile.get_style_context().add_class("toggle-tile")
        if self.bt_power:
            self.bt_tile.get_style_context().add_class("active")

        # Bluetooth Left Button (Toggle On/Off)
        bt_main = Gtk.Button()
        bt_main.get_style_context().add_class("toggle-main-btn")
        bt_main.connect("clicked", self.on_toggle_bt_clicked)
        bt_content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bt_main.add(bt_content)

        bt_icon_box = Gtk.Box()
        bt_icon_box.get_style_context().add_class("toggle-icon-badge")
        bt_icon_box.set_halign(Gtk.Align.CENTER)
        bt_icon_box.set_valign(Gtk.Align.CENTER)

        self.bt_icon_lbl = Gtk.Label(label="󰂯" if self.bt_power else "󰂲")
        self.bt_icon_lbl.get_style_context().add_class("toggle-badge-icon")
        self.bt_icon_lbl.set_xalign(0.5)
        self.bt_icon_lbl.set_yalign(0.5)
        self.bt_icon_lbl.set_halign(Gtk.Align.CENTER)
        self.bt_icon_lbl.set_valign(Gtk.Align.CENTER)
        bt_icon_box.pack_start(self.bt_icon_lbl, True, True, 0)
        bt_content.pack_start(bt_icon_box, False, False, 0)

        bt_text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        bt_text_box.set_valign(Gtk.Align.CENTER)
        b_title = Gtk.Label(label="Bluetooth")
        b_title.get_style_context().add_class("toggle-title")
        b_title.set_halign(Gtk.Align.START)
        bt_text_box.pack_start(b_title, False, False, 0)

        self.bt_sub = Gtk.Label(label=self.bt_dev if self.bt_power else "Disabled")
        self.bt_sub.get_style_context().add_class("toggle-sub")
        self.bt_sub.set_halign(Gtk.Align.START)
        self.bt_sub.set_ellipsize(3)
        self.bt_sub.set_max_width_chars(11)
        bt_text_box.pack_start(self.bt_sub, False, False, 0)
        bt_content.pack_start(bt_text_box, True, True, 0)

        self.bt_tile.pack_start(bt_main, True, True, 0)

        # Bluetooth Right Arrow (Open Sub-menu)
        bt_arrow = Gtk.Button()
        bt_arrow.get_style_context().add_class("toggle-arrow-btn")
        b_arr_lbl = Gtk.Label(label="󰅂")
        b_arr_lbl.get_style_context().add_class("arrow-icon")
        b_arr_lbl.set_xalign(0.5)
        b_arr_lbl.set_yalign(0.5)
        b_arr_lbl.set_halign(Gtk.Align.CENTER)
        b_arr_lbl.set_valign(Gtk.Align.CENTER)
        bt_arrow.add(b_arr_lbl)
        bt_arrow.set_tooltip_text("Open Bluetooth Devices Dropdown")
        bt_arrow.connect("clicked", lambda b: subprocess.Popen(["python3", "/home/Krish/.config/waybar/scripts/bluetooth-menu.py"]))
        self.bt_tile.pack_start(bt_arrow, False, False, 0)

        toggles_grid.pack_start(self.bt_tile, True, True, 0)

        # -------------------------------------------------------------
        # 4. Utility Row (3 Sleek Action Buttons)
        # -------------------------------------------------------------
        util_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        main_box.pack_start(util_box, False, False, 0)

        # Full Screenshot
        full_shot_btn = Gtk.Button()
        full_shot_btn.get_style_context().add_class("util-btn")
        f_lbl = Gtk.Label(label="󰹟 Fullscreen")
        f_lbl.set_xalign(0.5)
        f_lbl.set_yalign(0.5)
        full_shot_btn.add(f_lbl)
        full_shot_btn.set_tooltip_text("Capture Fullscreen")
        full_shot_btn.connect("clicked", self.on_take_full_screenshot)
        util_box.pack_start(full_shot_btn, True, True, 0)

        # Dunst / Notification toggle
        dunst_btn = Gtk.Button()
        dunst_btn.get_style_context().add_class("util-btn")
        d_lbl = Gtk.Label(label="󰂚 Notifications")
        d_lbl.set_xalign(0.5)
        d_lbl.set_yalign(0.5)
        dunst_btn.add(d_lbl)
        dunst_btn.set_tooltip_text("Toggle Notification Center")
        dunst_btn.connect("clicked", lambda b: subprocess.Popen(["dunstctl", "history-pop"]))
        util_box.pack_start(dunst_btn, True, True, 0)

        # Lock Screen button
        lock_btn = Gtk.Button()
        lock_btn.get_style_context().add_class("util-btn")
        l_lbl = Gtk.Label(label=" Lock")
        l_lbl.set_xalign(0.5)
        l_lbl.set_yalign(0.5)
        lock_btn.add(l_lbl)
        lock_btn.set_tooltip_text("Lock Session")
        lock_btn.connect("clicked", self.on_lock_screen)
        util_box.pack_start(lock_btn, True, True, 0)

        # Events
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", lambda w: self.cleanup())

    def get_vol_icon(self, val):
        if val >= 60:
            return "󰕾"
        elif val >= 25:
            return "󰖀"
        elif val > 0:
            return "󰕿"
        return "󰝟"

    def on_vol_change(self, scale):
        val = int(scale.get_value())
        self.vol_pct_lbl.set_text(f"{val}%")
        self.mute_lbl.set_text(self.get_vol_icon(val))
        set_volume(val)

    def on_toggle_mute(self, btn):
        toggle_mute()
        vol_val, is_muted = get_volume()
        self.mute_lbl.set_text("󰝟" if is_muted else self.get_vol_icon(vol_val))
        self.vol_pct_lbl.set_text("Muted" if is_muted else f"{vol_val}%")

    def on_bright_change(self, scale):
        val = int(scale.get_value())
        self.bright_pct_lbl.set_text(f"{val}%")
        set_brightness(val)

    def on_toggle_wifi_clicked(self, btn):
        self.wifi_radio = not self.wifi_radio
        toggle_wifi(self.wifi_radio)
        self.refresh_wifi_ui()
        GLib.timeout_add(800, self.refresh_wifi_async)

    def refresh_wifi_ui(self):
        ctx = self.wifi_tile.get_style_context()
        if self.wifi_radio:
            ctx.add_class("active")
            self.wifi_icon_lbl.set_text("󰤨")
            self.wifi_sub.set_text(self.wifi_ssid if self.wifi_ssid else "Connecting...")
        else:
            ctx.remove_class("active")
            self.wifi_icon_lbl.set_text("󰤮")
            self.wifi_sub.set_text("Disabled")

    def refresh_wifi_async(self):
        self.wifi_radio, self.wifi_ssid = get_wifi_status()
        self.refresh_wifi_ui()
        return False

    def on_toggle_bt_clicked(self, btn):
        self.bt_power = not self.bt_power
        toggle_bluetooth(self.bt_power)
        self.refresh_bt_ui()
        GLib.timeout_add(800, self.refresh_bt_async)

    def refresh_bt_ui(self):
        ctx = self.bt_tile.get_style_context()
        if self.bt_power:
            ctx.add_class("active")
            self.bt_icon_lbl.set_text("󰂯")
            self.bt_sub.set_text(self.bt_dev if self.bt_dev else "No device")
        else:
            ctx.remove_class("active")
            self.bt_icon_lbl.set_text("󰂲")
            self.bt_sub.set_text("Disabled")

    def refresh_bt_async(self):
        self.bt_power, self.bt_dev = get_bluetooth_status()
        self.refresh_bt_ui()
        return False

    def on_take_screenshot(self, btn):
        self.close_app()
        subprocess.Popen(["bash", "-c", "sleep 0.2; bash /home/Krish/.config/hypr/scripts/screenshot.sh area"])

    def on_take_full_screenshot(self, btn):
        self.close_app()
        subprocess.Popen(["bash", "-c", "sleep 0.2; bash /home/Krish/.config/hypr/scripts/screenshot.sh full"])

    def on_lock_screen(self, btn):
        self.close_app()
        subprocess.Popen(["loginctl", "lock-session"])

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

    win = QuickSettingsWindow()
    win.show_all()
    Gtk.main()
