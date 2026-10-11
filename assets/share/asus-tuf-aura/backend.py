#!/usr/bin/env python3
"""
ASUS TUF Gaming A15 Keyboard Backlight Controller Backend
Controls ASUS TUF Aura RGB keyboard backlight via Linux kernel asus-nb-wmi sysfs.
Integrates with desktop dynamic Material You theming (~/.config/my-desktop/theme/colors.json).
"""

import json
import logging
import os
import sys
from pathlib import Path
from typing import Dict, Any, Tuple, Optional

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ASUS-TUF-Backend")

SYSFS_LED = Path("/sys/class/leds/asus::kbd_backlight")
MODE_FILE = SYSFS_LED / "kbd_rgb_mode"
STATE_FILE = SYSFS_LED / "kbd_rgb_state"
BRIGHTNESS_FILE = SYSFS_LED / "brightness"
MAX_BRIGHTNESS_FILE = SYSFS_LED / "max_brightness"

CONFIG_DIR = Path.home() / ".config" / "asus-tuf-aura"
CONFIG_FILE = CONFIG_DIR / "config.json"
MATERIAL_YOU_FILE = Path.home() / ".config" / "my-desktop" / "theme" / "colors.json"

DEFAULT_CONFIG: Dict[str, Any] = {
    "mode": 0,  # 0: Static, 1: Breathing, 2: Color Cycle, 3: Strobing
    "mode_name": "Static",
    "color": [113, 217, 243],  # Material You Primary default (#71D9F3)
    "hex": "#71D9F3",
    "speed": 1,  # 0: Slow, 1: Normal, 2: Fast
    "brightness": 3,  # 0, 1, 2, 3
    "sync_material_you": True,
    "power_states": {
        "boot": 1,
        "awake": 1,
        "sleep": 0
    }
}

MODES = {
    0: "Static",
    1: "Breathing",
    2: "Color Cycle",
    3: "Strobing"
}

SPEEDS = {
    0: "Slow",
    1: "Normal",
    2: "Fast"
}


def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    clean = hex_str.lstrip("#")
    if len(clean) == 3:
        clean = "".join(c * 2 for c in clean)
    if len(clean) >= 6:
        return int(clean[0:2], 16), int(clean[2:4], 16), int(clean[4:6], 16)
    return 113, 217, 243


class TufKeyboardBackend:
    def __init__(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        self.config = self.load_config()

    def is_hardware_supported(self) -> bool:
        return MODE_FILE.exists() and BRIGHTNESS_FILE.exists()

    def get_material_you_palette(self) -> Dict[str, Any]:
        """Reads the active Material You palette extracted from wallpaper."""
        if MATERIAL_YOU_FILE.exists():
            try:
                with open(MATERIAL_YOU_FILE, "r") as f:
                    data = json.load(f)
                    return data
            except Exception as e:
                logger.warning(f"Failed to read Material You colors: {e}")
        return {
            "wallpaper": "Wallpaper",
            "colors": {
                "primary": "#71d9f3",
                "secondary": "#83d4fa",
                "background": "#0f1313",
                "surface": "#181e1f",
                "surface_variant": "#20292c",
                "outline": "#2f3d41"
            }
        }

    def load_config(self) -> Dict[str, Any]:
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r") as f:
                    cfg = json.load(f)
                    merged = dict(DEFAULT_CONFIG)
                    merged.update(cfg)
                    return merged
            except Exception as e:
                logger.warning(f"Failed to load config, using defaults: {e}")
        return dict(DEFAULT_CONFIG)

    def save_config(self) -> bool:
        try:
            with open(CONFIG_FILE, "w") as f:
                json.dump(self.config, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Failed to save config: {e}")
            return False

    def get_max_brightness(self) -> int:
        if MAX_BRIGHTNESS_FILE.exists():
            try:
                return int(MAX_BRIGHTNESS_FILE.read_text().strip())
            except Exception:
                pass
        return 3

    def get_current_brightness(self) -> int:
        if BRIGHTNESS_FILE.exists():
            try:
                return int(BRIGHTNESS_FILE.read_text().strip())
            except Exception:
                pass
        return self.config.get("brightness", 3)

    def set_brightness(self, level: int) -> bool:
        level = max(0, min(3, int(level)))
        self.config["brightness"] = level
        self.save_config()

        if not BRIGHTNESS_FILE.exists():
            logger.warning(f"Brightness file not found at {BRIGHTNESS_FILE}")
            return False

        try:
            with open(BRIGHTNESS_FILE, "w") as f:
                f.write(f"{level}\n")
            logger.info(f"Set brightness to {level}")
            return True
        except Exception as e:
            logger.error(f"Error setting brightness: {e}")
            return False

    def set_mode(self, mode: int, r: int, g: int, b: int, speed: int = 1) -> bool:
        """
        Write to kbd_rgb_mode.
        Format: "cmd mode red green blue speed"
        """
        mode = max(0, min(3, int(mode)))
        r = max(0, min(255, int(r)))
        g = max(0, min(255, int(g)))
        b = max(0, min(255, int(b)))
        speed = max(0, min(2, int(speed)))

        self.config["mode"] = mode
        self.config["mode_name"] = MODES.get(mode, "Static")
        self.config["color"] = [r, g, b]
        self.config["hex"] = f"#{r:02X}{g:02X}{b:02X}"
        self.config["speed"] = speed
        self.save_config()

        if not MODE_FILE.exists():
            logger.warning(f"Mode file not found at {MODE_FILE}")
            return False

        payload = f"0 {mode} {r} {g} {b} {speed}\n"
        try:
            with open(MODE_FILE, "w") as f:
                f.write(payload)
            logger.info(f"Applied mode: {payload.strip()}")
            return True
        except Exception as e:
            logger.error(f"Error setting mode: {e}")
            return False

    def set_power_states(self, boot: int, awake: int, sleep: int, persist: int = 1) -> bool:
        boot = 1 if boot else 0
        awake = 1 if awake else 0
        sleep = 1 if sleep else 0
        persist = 1 if persist else 0

        self.config["power_states"] = {
            "boot": boot,
            "awake": awake,
            "sleep": sleep
        }
        self.save_config()

        if not STATE_FILE.exists():
            logger.warning(f"State file not found at {STATE_FILE}")
            return False

        payload = f"{persist} {boot} {awake} {sleep} 1\n"
        try:
            with open(STATE_FILE, "w") as f:
                f.write(payload)
            logger.info(f"Applied power states: {payload.strip()}")
            return True
        except Exception as e:
            logger.error(f"Error setting power states: {e}")
            return False

    def apply_material_you(self, mode: Optional[int] = None) -> bool:
        """Applies current wallpaper Material You primary color to the keyboard backlight."""
        pal = self.get_material_you_palette()
        pri_hex = pal.get("colors", {}).get("primary", "#71d9f3")
        r, g, b = hex_to_rgb(pri_hex)
        
        target_mode = mode if mode is not None else self.config.get("mode", 0)
        speed = self.config.get("speed", 1)
        self.config["sync_material_you"] = True
        return self.set_mode(target_mode, r, g, b, speed)

    def restore_all(self) -> bool:
        """Restores all settings from config (and Material You if enabled) to hardware."""
        if self.config.get("sync_material_you", True):
            pal = self.get_material_you_palette()
            pri_hex = pal.get("colors", {}).get("primary", "#71d9f3")
            r, g, b = hex_to_rgb(pri_hex)
            self.config["color"] = [r, g, b]
            self.config["hex"] = pri_hex.upper()

        mode = self.config.get("mode", 0)
        col = self.config.get("color", [113, 217, 243])
        speed = self.config.get("speed", 1)
        brightness = self.config.get("brightness", 3)
        pstates = self.config.get("power_states", {"boot": 1, "awake": 1, "sleep": 0})

        b_res = self.set_brightness(brightness)
        m_res = self.set_mode(mode, col[0], col[1], col[2], speed)
        s_res = self.set_power_states(pstates.get("boot", 1), pstates.get("awake", 1), pstates.get("sleep", 0), persist=1)
        return b_res and m_res and s_res


if __name__ == "__main__":
    backend = TufKeyboardBackend()
    if len(sys.argv) > 1 and sys.argv[1] == "--material-you":
        print("Applying Material You wallpaper theme to keyboard backlight...")
        backend.apply_material_you()
    else:
        print("Restoring saved profile...")
        backend.restore_all()
    print("Done!")
