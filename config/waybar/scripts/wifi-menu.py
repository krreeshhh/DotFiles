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

PID_FILE = "/tmp/waybar_wifi_menu.pid"

# Close conflicting quick panels
for conflict in ["/tmp/waybar_quick_settings.pid", "/tmp/waybar_bt_menu.pid", "/tmp/waybar_battery_popup.pid"]:
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


def get_wifi_icon(signal_val):
    if signal_val >= 75:
        return "󰤨"
    elif signal_val >= 50:
        return "󰤥"
    elif signal_val >= 25:
        return "󰤢"
    elif signal_val > 0:
        return "󰤟"
    return "󰤯"


class WifiMenu(Gtk.Window):
    def __init__(self):
        super().__init__(title="WifiMenu")

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
        self.expanded_ssid = None

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
        .net-card {
            background-color: @theme_surface;
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 12px;
            padding: 8px 10px;
            margin-bottom: 4px;
            transition: all 0.15s ease;
        }
        .net-card:hover {
            background-color: @theme_surface_variant;
            border-color: rgba(255, 255, 255, 0.15);
        }
        .net-card.connected {
            background-color: @theme_primary_container;
            border-color: @theme_primary;
        }
        .net-icon {
            color: @theme_primary;
            font-size: 14px;
            min-width: 24px;
            margin-right: 2px;
        }
        .net-name {
            color: @theme_on_surface;
            font-size: 12px;
            font-weight: 600;
        }
        .net-details {
            color: @theme_on_surface_variant;
            font-size: 9.5px;
        }
        .net-status {
            color: @theme_primary;
            font-size: 10px;
            font-weight: 600;
        }
        .badge-saved {
            background-color: rgba(255, 255, 255, 0.08);
            color: @theme_on_surface_variant;
            border-radius: 6px;
            padding: 1px 5px;
            font-size: 8.5px;
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
        entry {
            background-color: @theme_surface_variant;
            color: @theme_on_surface;
            border: 1px solid @theme_border;
            border-radius: 8px;
            padding: 4px 8px;
            font-size: 10.5px;
        }
        entry:focus {
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

        icon_label = Gtk.Label(label="󰤨")
        icon_label.get_style_context().add_class("header-icon")
        icon_label.set_xalign(0.5)
        icon_label.set_yalign(0.5)
        header_box.pack_start(icon_label, False, False, 0)

        title = Gtk.Label(label="Wi-Fi Networks")
        title.get_style_context().add_class("header-title")
        header_box.pack_start(title, False, False, 0)

        header_box.pack_start(Gtk.Box(), True, True, 0)

        # Rescan button
        self.rescan_btn = Gtk.Button()
        self.rescan_btn.get_style_context().add_class("action-icon-btn")
        r_lbl = Gtk.Label(label="󰑮")
        r_lbl.set_xalign(0.5)
        r_lbl.set_yalign(0.5)
        r_lbl.set_halign(Gtk.Align.CENTER)
        r_lbl.set_valign(Gtk.Align.CENTER)
        self.rescan_btn.add(r_lbl)
        self.rescan_btn.set_tooltip_text("Rescan available Wi-Fi networks")
        self.rescan_btn.connect("clicked", self.on_rescan_clicked)
        header_box.pack_start(self.rescan_btn, False, False, 0)

        # nm-connection-editor shortcut
        mgr_btn = Gtk.Button()
        mgr_btn.get_style_context().add_class("action-icon-btn")
        m_lbl = Gtk.Label(label="")
        m_lbl.set_xalign(0.5)
        m_lbl.set_yalign(0.5)
        m_lbl.set_halign(Gtk.Align.CENTER)
        m_lbl.set_valign(Gtk.Align.CENTER)
        mgr_btn.add(m_lbl)
        mgr_btn.set_tooltip_text("Network Connections Editor")
        mgr_btn.connect("clicked", lambda b: subprocess.Popen(["nm-connection-editor"]))
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
        self.status_label = Gtk.Label(label="Scanning networks...")
        self.status_label.get_style_context().add_class("status-msg")
        self.status_bar.pack_start(self.status_label, False, False, 0)
        main_box.pack_start(self.status_bar, False, False, 0)

        # 2. Scrollable Network List
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

        # Periodic refresh timer (every 6 seconds)
        GLib.timeout_add_seconds(6, self.periodic_refresh)

    def on_back_to_quick_settings(self, btn):
        self.close_app()
        subprocess.Popen(["python3", "/home/Krish/.config/waybar/scripts/quick-settings.py"])

    def periodic_refresh(self):
        if not self.is_scanning and not self.expanded_ssid:
            self.refresh_all()
        return True

    def on_power_switch(self, switch, state):
        if getattr(self, "_updating_switch", False):
            return False
        cmd = ["nmcli", "radio", "wifi", "on" if state else "off"]
        subprocess.run(cmd, stderr=subprocess.DEVNULL)
        GLib.timeout_add(800, self.refresh_all)
        return False

    def on_rescan_clicked(self, btn):
        self.is_scanning = True
        self.status_label.set_text("Rescanning Wi-Fi networks...")
        def _scan():
            subprocess.run(["nmcli", "device", "wifi", "rescan"], stderr=subprocess.DEVNULL)
            GLib.usleep(1500000)
            GLib.idle_add(self._done_scan)
        threading.Thread(target=_scan, daemon=True).start()

    def _done_scan(self):
        self.is_scanning = False
        self.refresh_all()

    def refresh_all(self):
        threading.Thread(target=self._fetch_wifi_data, daemon=True).start()

    def _fetch_wifi_data(self):
        try:
            radio = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, stderr=subprocess.DEVNULL).strip() == "enabled"
        except Exception:
            radio = False

        if not radio:
            GLib.idle_add(self._render_off)
            return

        saved_conns = set()
        try:
            conns = subprocess.check_output(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], text=True, stderr=subprocess.DEVNULL).strip().splitlines()
            for c in conns:
                if ":802-11-wireless" in c:
                    saved_conns.add(c.split(":")[0])
        except Exception:
            pass

        networks = {}
        try:
            rescan_flag = "yes" if self.is_scanning else "no"
            out = subprocess.check_output(
                ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan_flag],
                text=True,
                stderr=subprocess.DEVNULL
            ).strip().splitlines()
            for line in out:
                parts = line.split(":")
                if len(parts) >= 4:
                    in_use = parts[0].strip() == "*"
                    ssid = parts[1].strip()
                    if not ssid:
                        continue
                    try:
                        signal_val = int(parts[2].strip())
                    except ValueError:
                        signal_val = 0
                    sec = parts[3].strip()
                    is_secure = bool(sec and sec != "--")

                    if ssid not in networks or in_use or signal_val > networks[ssid]["signal"]:
                        networks[ssid] = {
                            "ssid": ssid,
                            "in_use": in_use,
                            "signal": signal_val,
                            "secure": is_secure,
                            "security_desc": sec,
                            "saved": ssid in saved_conns
                        }
        except Exception:
            pass

        net_list = sorted(networks.values(), key=lambda n: (not n["in_use"], -n["signal"]))
        GLib.idle_add(self._render_networks, radio, net_list)

    def _render_off(self):
        self._updating_switch = True
        self.power_switch.set_active(False)
        self._updating_switch = False
        self.status_label.set_text("Wi-Fi is turned off")
        for child in self.list_box.get_children():
            self.list_box.remove(child)

        off_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        off_box.set_margin_top(40)
        off_box.set_halign(Gtk.Align.CENTER)

        off_icon = Gtk.Label(label="󰤮")
        off_icon.get_style_context().add_class("net-icon")
        off_box.pack_start(off_icon, False, False, 0)

        off_lbl = Gtk.Label(label="Wi-Fi Disabled")
        off_lbl.get_style_context().add_class("net-name")
        off_box.pack_start(off_lbl, False, False, 0)

        turn_on_btn = Gtk.Button(label="Turn On Wi-Fi")
        turn_on_btn.get_style_context().add_class("action-btn")
        turn_on_btn.get_style_context().add_class("btn-connect")
        turn_on_btn.connect("clicked", lambda b: self.on_power_switch(None, True))
        off_box.pack_start(turn_on_btn, False, False, 0)

        self.list_box.pack_start(off_box, True, True, 0)
        self.list_box.show_all()

    def _render_networks(self, radio, networks):
        self._updating_switch = True
        self.power_switch.set_active(True)
        self._updating_switch = False
        connected_net = next((n for n in networks if n["in_use"]), None)

        if connected_net:
            self.status_label.set_text(f"Connected to {connected_net['ssid']} • {connected_net['signal']}% Signal")
        else:
            self.status_label.set_text(f"{len(networks)} networks available")

        for child in self.list_box.get_children():
            self.list_box.remove(child)

        # 1. Connected Network
        if connected_net:
            lbl = Gtk.Label(label="CONNECTED")
            lbl.get_style_context().add_class("section-header")
            lbl.set_halign(Gtk.Align.START)
            self.list_box.pack_start(lbl, False, False, 0)

            self.list_box.pack_start(self._create_network_card(connected_net), False, False, 0)

        # 2. Available Networks
        other_nets = [n for n in networks if not n["in_use"]]
        if other_nets:
            lbl = Gtk.Label(label="AVAILABLE NETWORKS")
            lbl.get_style_context().add_class("section-header")
            lbl.set_halign(Gtk.Align.START)
            self.list_box.pack_start(lbl, False, False, 0)

            for n in other_nets:
                self.list_box.pack_start(self._create_network_card(n), False, False, 0)

        if not networks:
            empty_lbl = Gtk.Label(label="No Wi-Fi networks found.\nClick 󰑮 to rescan.")
            empty_lbl.get_style_context().add_class("status-msg")
            empty_lbl.set_margin_top(40)
            self.list_box.pack_start(empty_lbl, True, True, 0)

        self.list_box.show_all()

    def _create_network_card(self, net):
        card_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        card_box.get_style_context().add_class("net-card")
        if net["in_use"]:
            card_box.get_style_context().add_class("connected")

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        card_box.pack_start(row, False, False, 0)

        # Signal Icon
        sig_icon = Gtk.Label(label=get_wifi_icon(net["signal"]))
        sig_icon.get_style_context().add_class("net-icon")
        sig_icon.set_halign(Gtk.Align.CENTER)
        row.pack_start(sig_icon, False, False, 0)

        # SSID & Info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        name_lbl = Gtk.Label(label=net["ssid"])
        name_lbl.get_style_context().add_class("net-name")
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.set_ellipsize(3)
        name_lbl.set_max_width_chars(16)
        title_row.pack_start(name_lbl, False, False, 0)

        if net["secure"]:
            sec_icon = Gtk.Label(label="")
            sec_icon.get_style_context().add_class("net-details")
            sec_icon.set_tooltip_text(f"Secured ({net['security_desc']})")
            title_row.pack_start(sec_icon, False, False, 0)

        if net["saved"] and not net["in_use"]:
            saved_badge = Gtk.Label(label="Saved")
            saved_badge.get_style_context().add_class("badge-saved")
            title_row.pack_start(saved_badge, False, False, 0)

        info_box.pack_start(title_row, False, False, 0)

        # Subtitle
        if net["in_use"]:
            sub_lbl = Gtk.Label(label="Connected")
            sub_lbl.get_style_context().add_class("net-status")
        else:
            sub_lbl = Gtk.Label(label=f"Signal: {net['signal']}%")
            sub_lbl.get_style_context().add_class("net-details")
        sub_lbl.set_halign(Gtk.Align.START)
        info_box.pack_start(sub_lbl, False, False, 0)

        row.pack_start(info_box, True, True, 0)

        # Action Button
        if net["in_use"]:
            disc_btn = Gtk.Button(label="Disconnect")
            disc_btn.get_style_context().add_class("action-btn")
            disc_btn.get_style_context().add_class("btn-disconnect")
            disc_btn.connect("clicked", lambda b, s=net["ssid"]: self.disconnect_network(s))
            row.pack_start(disc_btn, False, False, 0)
        elif net["saved"] or not net["secure"]:
            conn_btn = Gtk.Button(label="Connect")
            conn_btn.get_style_context().add_class("action-btn")
            conn_btn.get_style_context().add_class("btn-connect")
            conn_btn.connect("clicked", lambda b, s=net["ssid"]: self.connect_saved(s))
            row.pack_start(conn_btn, False, False, 0)
        else:
            is_expanded = (self.expanded_ssid == net["ssid"])
            pass_btn = Gtk.Button(label="Cancel" if is_expanded else "Connect")
            pass_btn.get_style_context().add_class("action-btn")
            pass_btn.get_style_context().add_class("btn-connect")
            pass_btn.connect("clicked", lambda b, s=net["ssid"]: self.toggle_password_row(s))
            row.pack_start(pass_btn, False, False, 0)

            if is_expanded:
                pass_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                pass_box.set_margin_top(6)

                entry = Gtk.Entry()
                entry.set_visibility(False)
                entry.set_placeholder_text("Enter Wi-Fi Password...")
                pass_box.pack_start(entry, True, True, 0)

                submit_btn = Gtk.Button(label="Join")
                submit_btn.get_style_context().add_class("action-btn")
                submit_btn.get_style_context().add_class("btn-connect")
                submit_btn.connect("clicked", lambda b, s=net["ssid"], e=entry: self.connect_with_password(s, e.get_text()))
                entry.connect("activate", lambda e, s=net["ssid"]: self.connect_with_password(s, e.get_text()))
                pass_box.pack_start(submit_btn, False, False, 0)

                card_box.pack_start(pass_box, False, False, 0)

        return card_box

    def toggle_password_row(self, ssid):
        if self.expanded_ssid == ssid:
            self.expanded_ssid = None
        else:
            self.expanded_ssid = ssid
        self.refresh_all()

    def connect_saved(self, ssid):
        self.status_label.set_text(f"Connecting to {ssid}...")
        def _task():
            res = subprocess.run(["nmcli", "connection", "up", "id", ssid], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode != 0:
                subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

    def connect_with_password(self, ssid, password):
        if not password:
            self.status_label.set_text("Please enter a password.")
            return
        self.status_label.set_text(f"Connecting to {ssid}...")
        self.expanded_ssid = None
        def _task():
            res = subprocess.run(["nmcli", "dev", "wifi", "connect", ssid, "password", password], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if res.returncode == 0:
                GLib.idle_add(lambda: self.status_label.set_text(f"Connected to {ssid}!"))
            else:
                err = res.stderr.strip() or "Connection failed"
                GLib.idle_add(lambda: self.status_label.set_text(f"Failed: {err[:35]}"))
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

    def disconnect_network(self, ssid):
        self.status_label.set_text(f"Disconnecting {ssid}...")
        def _task():
            subprocess.run(["nmcli", "connection", "down", "id", ssid], stderr=subprocess.DEVNULL)
            GLib.idle_add(self.refresh_all)
        threading.Thread(target=_task, daemon=True).start()

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

    win = WifiMenu()
    win.show_all()
    Gtk.main()
