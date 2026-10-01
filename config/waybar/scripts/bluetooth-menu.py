#!/usr/bin/env python3
import os
import sys
import subprocess
import signal
import threading
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

PID_FILE = "/tmp/waybar_bt_menu.pid"

# Close conflicting quick panels
for conflict in ["/tmp/waybar_quick_settings.pid", "/tmp/waybar_wifi_menu.pid", "/tmp/waybar_battery_popup.pid"]:
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


def get_bt_icon(name):
    name_lower = name.lower()
    if any(k in name_lower for k in ["bud", "ear", "headphone", "headset", "airpod", "audio", "sound"]):
        return "󰋋"
    elif any(k in name_lower for k in ["mouse", "trackpad"]):
        return "󰍽"
    elif any(k in name_lower for k in ["keyboard", "key"]):
        return "󰌌"
    elif any(k in name_lower for k in ["phone", "iphone", "android", "galaxy"]):
        return ""
    elif any(k in name_lower for k in ["watch", "band"]):
        return "󰥔"
    elif any(k in name_lower for k in ["pad", "controller", "game"]):
        return "󰊴"
    return "󰂯"


class BluetoothMenu(Gtk.Window):
    def __init__(self):
        super().__init__(title="BluetoothMenu")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 6)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 12)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        self.set_default_size(360, 380)
        self.set_decorated(False)
        self.set_resizable(False)

        self.is_scanning = False
        self.scan_proc = None

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
        button label {
            color: inherit;
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
        .header-icon {
            color: @theme_primary;
            font-size: 15px;
            margin-right: 2px;
        }
        .status-msg {
            color: @theme_on_surface_variant;
            font-size: 10.5px;
            font-weight: 500;
        }
        .section-header {
            color: @theme_on_surface_variant;
            font-size: 9.5px;
            font-weight: 700;
            letter-spacing: 0.5px;
            margin-top: 6px;
            margin-bottom: 2px;
        }
        .device-card {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            padding: 8px 10px;
            margin-bottom: 4px;
            transition: all 0.15s ease;
        }
        .device-card:hover {
            background-color: @theme_surface_variant;
            border-color: rgba(255, 255, 255, 0.15);
        }
        .device-card.connected {
            background-color: @theme_primary_container;
            border-color: @theme_primary;
        }
        .device-icon {
            color: @theme_primary;
            font-size: 15px;
            min-width: 24px;
            margin-right: 2px;
        }
        .device-name {
            color: @theme_on_surface;
            font-size: 12px;
            font-weight: 600;
        }
        .device-mac {
            color: @theme_on_surface_variant;
            font-size: 9.5px;
        }
        .device-status {
            color: @theme_primary;
            font-size: 10px;
            font-weight: 600;
        }
        .action-btn {
            border-radius: 8px;
            padding: 4px 10px;
            font-size: 11px;
            font-weight: 700;
            transition: all 0.15s ease;
        }
        .btn-connect {
            background-color: @theme_surface_selected;
            color: @theme_primary;
            border: 1px solid @theme_primary;
        }
        .btn-connect:hover {
            background-color: @theme_primary;
            color: @theme_on_primary;
            border-color: @theme_primary;
        }
        .btn-disconnect {
            background-color: rgba(255, 107, 107, 0.12);
            color: @theme_error;
            border: 1px solid rgba(255, 107, 107, 0.4);
        }
        .btn-disconnect:hover {
            background-color: @theme_error;
            color: #ffffff;
            border-color: @theme_error;
        }
        .btn-pair {
            background-color: @theme_surface_variant;
            color: @theme_on_surface;
            border: 1px solid rgba(255, 255, 255, 0.12);
        }
        .btn-pair:hover {
            background-color: @theme_primary;
            color: @theme_on_primary;
            border-color: @theme_primary;
        }
        switch {
            border-radius: 12px;
            background-color: @theme_surface_variant;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        switch:checked {
            background-color: @theme_primary;
            border-color: @theme_primary;
        }
        switch slider {
            border-radius: 50%;
            background-color: #ffffff;
            min-width: 14px;
            min-height: 14px;
        }
        scrollbar slider {
            background-color: rgba(255, 255, 255, 0.15);
            border-radius: 4px;
        }
        scrollbar slider:hover {
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

        # 1. Header
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        main_box.pack_start(header_box, False, False, 0)

        # Back to Quick Settings button
        back_btn = Gtk.Button()
        back_btn.get_style_context().add_class("action-icon-btn")
        b_lbl = Gtk.Label(label="󰅁")
        b_lbl.set_xalign(0.5)
        b_lbl.set_yalign(0.5)
        b_lbl.set_halign(Gtk.Align.CENTER)
        b_lbl.set_valign(Gtk.Align.CENTER)
        back_btn.add(b_lbl)
        back_btn.set_tooltip_text("Back to Quick Settings")
        back_btn.connect("clicked", self.on_back_to_quick_settings)
        header_box.pack_start(back_btn, False, False, 0)

        icon_label = Gtk.Label(label="󰂯")
        icon_label.get_style_context().add_class("header-icon")
        icon_label.set_xalign(0.5)
        icon_label.set_yalign(0.5)
        header_box.pack_start(icon_label, False, False, 0)

        title = Gtk.Label(label="Bluetooth Devices")
        title.get_style_context().add_class("header-title")
        header_box.pack_start(title, False, False, 0)

        header_box.pack_start(Gtk.Box(), True, True, 0)

        # Rescan button
        self.scan_btn = Gtk.Button()
        self.scan_btn.get_style_context().add_class("action-icon-btn")
        s_lbl = Gtk.Label(label="󰑮")
        s_lbl.set_xalign(0.5)
        s_lbl.set_yalign(0.5)
        s_lbl.set_halign(Gtk.Align.CENTER)
        s_lbl.set_valign(Gtk.Align.CENTER)
        self.scan_btn.add(s_lbl)
        self.scan_btn.set_tooltip_text("Scan for nearby Bluetooth devices")
        self.scan_btn.connect("clicked", self.on_toggle_scan)
        header_box.pack_start(self.scan_btn, False, False, 0)

        # Blueman manager shortcut
        mgr_btn = Gtk.Button()
        mgr_btn.get_style_context().add_class("action-icon-btn")
        m_lbl = Gtk.Label(label="")
        m_lbl.set_xalign(0.5)
        m_lbl.set_yalign(0.5)
        m_lbl.set_halign(Gtk.Align.CENTER)
        m_lbl.set_valign(Gtk.Align.CENTER)
        mgr_btn.add(m_lbl)
        mgr_btn.set_tooltip_text("Bluetooth Device Manager")
        mgr_btn.connect("clicked", lambda b: subprocess.Popen(["blueman-manager"]))
        header_box.pack_start(mgr_btn, False, False, 0)

        # Power Switch
        self.power_switch = Gtk.Switch()
        self.power_switch.connect("state-set", self.on_power_switch)
        header_box.pack_start(self.power_switch, False, False, 0)

        # Close button
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

        # Subtitle Status
        self.status_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.status_label = Gtk.Label(label="Checking status...")
        self.status_label.get_style_context().add_class("status-msg")
        self.status_bar.pack_start(self.status_label, False, False, 0)
        main_box.pack_start(self.status_bar, False, False, 0)

        # 2. Scrollable Device List
        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroll.set_min_content_height(250)
        main_box.pack_start(self.scroll, True, True, 0)

        self.list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.scroll.add(self.list_box)

        # Events
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", lambda w: self.cleanup())

        # Initial fetch
        self.refresh_all()

        # Periodic refresh timer (every 4 seconds)
        GLib.timeout_add_seconds(4, self.periodic_refresh)

    def on_back_to_quick_settings(self, btn):
        self.close_app()
        subprocess.Popen(["python3", "/home/Krish/.config/waybar/scripts/quick-settings.py"])

    def periodic_refresh(self):
        if not self.is_scanning:
            self.refresh_all()
        return True

    def on_power_switch(self, switch, state):
        if getattr(self, "_updating_switch", False):
            return False
        cmd = ["bluetoothctl", "power", "on" if state else "off"]
        subprocess.run(cmd, stderr=subprocess.DEVNULL)
        GLib.timeout_add(600, self.refresh_all)
        return False

    def on_toggle_scan(self, btn):
        if self.is_scanning:
            self.stop_scan()
        else:
            self.start_scan()

    def start_scan(self):
        self.is_scanning = True
        self.status_label.set_text("Scanning for nearby devices...")
        threading.Thread(target=self._run_scan, daemon=True).start()

    def _run_scan(self):
        try:
            self.scan_proc = subprocess.Popen(["bluetoothctl", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for _ in range(8):
                if not self.is_scanning:
                    break
                GLib.idle_add(self.refresh_all)
                GLib.usleep(1000000)
        finally:
            GLib.idle_add(self.stop_scan)

    def stop_scan(self):
        self.is_scanning = False
        if self.scan_proc:
            try:
                self.scan_proc.terminate()
            except Exception:
                pass
            self.scan_proc = None
        subprocess.run(["bluetoothctl", "scan", "off"], stderr=subprocess.DEVNULL)
        self.status_label.set_text("Scan finished")
        self.refresh_all()

    def refresh_all(self):
        threading.Thread(target=self._fetch_bt_data, daemon=True).start()

    def _fetch_bt_data(self):
        try:
            ctrl = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL)
            powered = "Powered: yes" in ctrl
        except Exception:
            powered = False

        if not powered:
            GLib.idle_add(self._render_off)
            return

        all_devs = []
        paired_devs = []
        conn_devs = []

        try:
            all_out = subprocess.check_output(["bluetoothctl", "devices"], text=True, stderr=subprocess.DEVNULL).strip()
            if all_out:
                all_devs = all_out.splitlines()
        except Exception:
            pass

        try:
            paired_out = subprocess.check_output(["bluetoothctl", "devices", "Paired"], text=True, stderr=subprocess.DEVNULL).strip()
            if paired_out:
                paired_devs = paired_out.splitlines()
        except Exception:
            pass

        try:
            conn_out = subprocess.check_output(["bluetoothctl", "devices", "Connected"], text=True, stderr=subprocess.DEVNULL).strip()
            if conn_out:
                conn_devs = conn_out.splitlines()
        except Exception:
            pass

        conn_macs = set()
        for l in conn_devs:
            p = l.split(" ", 2)
            if len(p) >= 2:
                conn_macs.add(p[1])

        paired_macs = set()
        for l in paired_devs:
            p = l.split(" ", 2)
            if len(p) >= 2:
                paired_macs.add(p[1])

        connected = []
        paired = []
        available = []

        for l in all_devs:
            p = l.split(" ", 2)
            if len(p) >= 3:
                mac, name = p[1], p[2]
                dev = {"mac": mac, "name": name}
                if mac in conn_macs:
                    connected.append(dev)
                elif mac in paired_macs:
                    paired.append(dev)
                else:
                    available.append(dev)

        GLib.idle_add(self._render_devices, powered, connected, paired, available)

    def _render_off(self):
        self._updating_switch = True
        self.power_switch.set_active(False)
        self._updating_switch = False
        self.status_label.set_text("Bluetooth is turned off")
        for child in self.list_box.get_children():
            self.list_box.remove(child)

        off_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        off_box.set_margin_top(40)
        off_box.set_halign(Gtk.Align.CENTER)

        off_icon = Gtk.Label(label="󰂲")
        off_icon.get_style_context().add_class("device-icon")
        off_box.pack_start(off_icon, False, False, 0)

        off_lbl = Gtk.Label(label="Bluetooth Disabled")
        off_lbl.get_style_context().add_class("device-name")
        off_box.pack_start(off_lbl, False, False, 0)

        turn_on_btn = Gtk.Button(label="Turn On Bluetooth")
        turn_on_btn.get_style_context().add_class("action-btn")
        turn_on_btn.get_style_context().add_class("btn-connect")
        turn_on_btn.connect("clicked", lambda b: self.on_power_switch(None, True))
        off_box.pack_start(turn_on_btn, False, False, 0)

        self.list_box.pack_start(off_box, True, True, 0)
        self.list_box.show_all()

    def _render_devices(self, powered, connected, paired, available):
        self._updating_switch = True
        self.power_switch.set_active(True)
        self._updating_switch = False
        if not self.is_scanning:
            total = len(connected) + len(paired) + len(available)
            self.status_label.set_text(f"{len(connected)} Connected • {total} Devices")

        for child in self.list_box.get_children():
            self.list_box.remove(child)

        # 1. Connected Devices
        if connected:
            lbl = Gtk.Label(label="CONNECTED")
            lbl.get_style_context().add_class("section-header")
            lbl.set_halign(Gtk.Align.START)
            self.list_box.pack_start(lbl, False, False, 0)

            for d in connected:
                self.list_box.pack_start(self._create_device_row(d, "connected"), False, False, 0)

        # 2. Paired Devices
        if paired:
            lbl = Gtk.Label(label="PAIRED DEVICES")
            lbl.get_style_context().add_class("section-header")
            lbl.set_halign(Gtk.Align.START)
            self.list_box.pack_start(lbl, False, False, 0)

            for d in paired:
                self.list_box.pack_start(self._create_device_row(d, "paired"), False, False, 0)

        # 3. Available / Discovered Devices
        if available:
            lbl = Gtk.Label(label="DISCOVERED NEARBY")
            lbl.get_style_context().add_class("section-header")
            lbl.set_halign(Gtk.Align.START)
            self.list_box.pack_start(lbl, False, False, 0)

            for d in available:
                self.list_box.pack_start(self._create_device_row(d, "available"), False, False, 0)

        if not connected and not paired and not available:
            empty_lbl = Gtk.Label(label="No devices found.\nClick 󰑮 to scan for nearby devices.")
            empty_lbl.get_style_context().add_class("status-msg")
            empty_lbl.set_margin_top(40)
            self.list_box.pack_start(empty_lbl, True, True, 0)

        self.list_box.show_all()

    def _create_device_row(self, dev, mode):
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        card.get_style_context().add_class("device-card")
        if mode == "connected":
            card.get_style_context().add_class("connected")

        # Icon
        icon_str = get_bt_icon(dev["name"])
        icon_lbl = Gtk.Label(label=icon_str)
        icon_lbl.get_style_context().add_class("device-icon")
        icon_lbl.set_halign(Gtk.Align.CENTER)
        card.pack_start(icon_lbl, False, False, 0)

        # Name & MAC
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        name_lbl = Gtk.Label(label=dev["name"])
        name_lbl.get_style_context().add_class("device-name")
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.set_ellipsize(3)
        name_lbl.set_max_width_chars(16)
        info_box.pack_start(name_lbl, False, False, 0)

        if mode == "connected":
            status_lbl = Gtk.Label(label="Connected")
            status_lbl.get_style_context().add_class("device-status")
            status_lbl.set_halign(Gtk.Align.START)
            info_box.pack_start(status_lbl, False, False, 0)
        else:
            mac_lbl = Gtk.Label(label=dev["mac"])
            mac_lbl.get_style_context().add_class("device-mac")
            mac_lbl.set_halign(Gtk.Align.START)
            info_box.pack_start(mac_lbl, False, False, 0)

        card.pack_start(info_box, True, True, 0)

        # Action Button
        if mode == "connected":
            btn = Gtk.Button(label="Disconnect")
            btn.get_style_context().add_class("action-btn")
            btn.get_style_context().add_class("btn-disconnect")
            btn.connect("clicked", lambda b, m=dev["mac"]: self.disconnect_device(m))
            card.pack_start(btn, False, False, 0)
        elif mode == "paired":
            btn = Gtk.Button(label="Connect")
            btn.get_style_context().add_class("action-btn")
            btn.get_style_context().add_class("btn-connect")
            btn.connect("clicked", lambda b, m=dev["mac"]: self.connect_device(m))
            card.pack_start(btn, False, False, 0)
        else:
            btn = Gtk.Button(label="Pair")
            btn.get_style_context().add_class("action-btn")
            btn.get_style_context().add_class("btn-pair")
            btn.connect("clicked", lambda b, m=dev["mac"]: self.pair_device(m))
            card.pack_start(btn, False, False, 0)

        return card

    def connect_device(self, mac):
        self.status_label.set_text(f"Connecting to {mac}...")
        def _task():
            subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL)
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

    def disconnect_device(self, mac):
        self.status_label.set_text(f"Disconnecting {mac}...")
        def _task():
            subprocess.run(["bluetoothctl", "disconnect", mac], stderr=subprocess.DEVNULL)
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

    def pair_device(self, mac):
        self.status_label.set_text(f"Pairing with {mac}...")
        def _task():
            subprocess.run(["bluetoothctl", "pair", mac], stderr=subprocess.DEVNULL)
            subprocess.run(["bluetoothctl", "trust", mac], stderr=subprocess.DEVNULL)
            subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL)
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

    def on_key_press(self, widget, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.close_app()

    def close_app(self):
        self.cleanup()
        Gtk.main_quit()

    def cleanup(self):
        if self.scan_proc:
            try:
                self.scan_proc.terminate()
            except Exception:
                pass
        subprocess.run(["bluetoothctl", "scan", "off"], stderr=subprocess.DEVNULL)
        if os.path.exists(PID_FILE):
            try:
                os.remove(PID_FILE)
            except OSError:
                pass


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))

    win = BluetoothMenu()
    win.show_all()
    Gtk.main()
