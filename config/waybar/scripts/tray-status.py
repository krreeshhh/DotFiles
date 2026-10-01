#!/usr/bin/env python3
import subprocess
import json
import sys

def get_tray_count():
    try:
        out = subprocess.check_output(
            [
                "busctl", "--user", "call",
                "org.kde.StatusNotifierWatcher",
                "/StatusNotifierWatcher",
                "org.freedesktop.DBus.Properties",
                "Get", "ss",
                "org.kde.StatusNotifierWatcher",
                "RegisteredStatusNotifierItems"
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1
        )
        parts = out.strip().split()
        if len(parts) >= 3 and parts[0] == "v" and parts[1] == "as":
            return int(parts[2])
    except Exception:
        pass
    return 0

count = get_tray_count()
if count > 0:
    print(json.dumps({
        "text": "",
        "tooltip": f"System Tray ({count} background app{'s' if count > 1 else ''}) - Click to expand",
        "class": "has-items"
    }))
else:
    print(json.dumps({
        "text": "",
        "tooltip": "",
        "class": "empty"
    }))
sys.stdout.flush()
