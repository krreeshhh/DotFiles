#!/usr/bin/env python3
"""
XDG Autostart Manager for Hyprland
Reads and executes ~/.config/autostart/*.desktop entries managed by applications.
"""
import glob
import os
import shlex
import subprocess
import configparser
import sys

AUTOSTART_DIR = os.path.expanduser("~/.config/autostart")

def run_autostart():
    if not os.path.isdir(AUTOSTART_DIR):
        return

    desktop_files = sorted(glob.glob(os.path.join(AUTOSTART_DIR, "*.desktop")))
    for path in desktop_files:
        try:
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            cp.read(path, encoding="utf-8")
            sec = "Desktop Entry"
            if not cp.has_section(sec):
                continue

            # Check if disabled by application
            if cp.has_option(sec, "Hidden") and cp.getboolean(sec, "Hidden"):
                continue
            if cp.has_option(sec, "X-GNOME-Autostart-enabled") and not cp.getboolean(sec, "X-GNOME-Autostart-enabled"):
                continue

            # Check NotShowIn restrictions
            if cp.has_option(sec, "NotShowIn"):
                not_in = [s.strip().lower() for s in cp.get(sec, "NotShowIn").split(";") if s.strip()]
                if "hyprland" in not_in:
                    continue

            # Check TryExec
            if cp.has_option(sec, "TryExec"):
                try_exec = cp.get(sec, "TryExec").strip()
                if not os.path.isabs(try_exec):
                    if subprocess.call(["which", try_exec], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0:
                        continue
                elif not os.path.exists(try_exec):
                    continue

            # Check Exec
            if not cp.has_option(sec, "Exec"):
                continue

            exec_str = cp.get(sec, "Exec").strip()
            if not exec_str:
                continue

            # Remove XDG field codes (%f, %F, %u, %U, %i, %c, %k, %v, %m)
            tokens = []
            for token in shlex.split(exec_str):
                if token.startswith("%") and len(token) == 2:
                    continue
                tokens.append(token)

            if not tokens:
                continue

            # Launch detached in background
            subprocess.Popen(
                tokens,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            print(f"Autostarted: {os.path.basename(path)} -> {tokens}")
        except Exception as e:
            print(f"Error starting {path}: {e}", file=sys.stderr)

if __name__ == "__main__":
    run_autostart()
