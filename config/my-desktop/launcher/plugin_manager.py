#!/usr/bin/env python3
"""
Omarchy Plugin Manager for Desktop Launcher
Discovers, manages, installs, and removes Quickshell plugins installed via omarchy.
"""

import os
import sys
import json
import glob
import shlex
import subprocess

PLUGINS_DIR = os.path.expanduser("~/.config/quickshell/plugins")
BAR_QML = os.path.expanduser("~/.config/quickshell/bar/Bar.qml")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RASI_THEME = os.path.join(SCRIPT_DIR, "launcher.rasi")

os.makedirs(PLUGINS_DIR, exist_ok=True)


def list_plugins():
    """Returns a list of all installed Omarchy plugins with full metadata."""
    if not os.path.exists(PLUGINS_DIR):
        return []

    bar_content = ""
    if os.path.exists(BAR_QML):
        try:
            with open(BAR_QML, "r", encoding="utf-8", errors="ignore") as f:
                bar_content = f.read()
        except Exception:
            pass

    plugins = []
    for entry in sorted(os.listdir(PLUGINS_DIR)):
        plugin_path = os.path.join(PLUGINS_DIR, entry)
        if not os.path.isdir(plugin_path):
            continue

        manifest_path = os.path.join(plugin_path, "manifest.json")
        has_qml = any(os.path.exists(os.path.join(plugin_path, f)) for f in ["BarWidget.qml", "Panel.qml", "LedgeWidget.qml", "Service.qml"])
        if not os.path.exists(manifest_path) and not has_qml:
            continue
        manifest = {}
        if os.path.exists(manifest_path):
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
            except Exception:
                pass

        name = manifest.get("name", entry.replace("omarchy-", "").capitalize())
        plugin_id = manifest.get("id", entry)
        version = manifest.get("version", "")
        description = manifest.get("description", "Quickshell desktop plugin")
        author = manifest.get("author", "")
        kinds = manifest.get("kinds", [])
        entry_points = manifest.get("entryPoints", {})

        # Determine icon (prefer local icon if present, fallback to outline preferences-plugin-symbolic)
        icon = manifest.get("icon", "preferences-plugin-symbolic")
        for ic_name in ["icon.png", "icon.svg", f"{entry}.png", f"{entry}.svg", "logo.png", "logo.svg"]:
            ic_path = os.path.join(plugin_path, ic_name)
            if os.path.exists(ic_path):
                icon = ic_path
                break

        # Check if enabled in Bar.qml
        widget_file = entry_points.get("barWidget", "")
        widget_name = widget_file.replace(".qml", "") if widget_file else ""
        is_enabled = (
            f"plugins/{entry}" in bar_content
            or (widget_name and widget_name in bar_content)
        )

        # Detect executable CLI
        exec_cmd = None
        bin_exact = os.path.expanduser(f"~/.local/bin/{entry}")
        bin_short = os.path.expanduser(f"~/.local/bin/omarchy-{entry.replace('omarchy-', '')}")
        bin_plain = os.path.expanduser(f"~/.local/bin/{entry.replace('omarchy-', '')}")

        if os.path.exists(bin_exact):
            exec_cmd = entry
        elif os.path.exists(bin_short):
            exec_cmd = f"omarchy-{entry.replace('omarchy-', '')}"
        elif os.path.exists(bin_plain):
            exec_cmd = entry.replace('omarchy-', '')
        elif os.path.exists(os.path.join(plugin_path, "run.sh")):
            exec_cmd = os.path.join(plugin_path, "run.sh")

        plugins.append({
            "dir": entry,
            "id": plugin_id,
            "name": name,
            "version": version,
            "description": description,
            "author": author,
            "icon": icon,
            "enabled": is_enabled,
            "path": plugin_path,
            "exec": exec_cmd,
            "entryPoints": entry_points,
            "kinds": kinds
        })

    return plugins


def prompt_rofi(prompt, placeholder=""):
    """Opens a Material You Rofi single-line dmenu prompt."""
    cmd = [
        "rofi",
        "-dmenu",
        "-i",
        "-p", prompt,
        "-theme", RASI_THEME
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, _ = p.communicate(input=placeholder)
    if p.returncode != 0 or not out.strip():
        return None
    return out.strip()


def prompt_quickshell(title="Input Prompt", prompt="", placeholder="Enter value...", default_value="", icon="󰏗"):
    """
    Shows the native Quickshell PromptDialog if Quickshell is running.
    Falls back gracefully to Material You styled Rofi.
    """
    import time
    rundir = f"/run/user/{os.getuid()}/quickshell-prompts"
    os.makedirs(rundir, exist_ok=True)
    os.chmod(rundir, 0o700)

    is_qs_running = False
    try:
        res = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "quickshell"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        is_qs_running = res.returncode == 0
    except Exception:
        pass

    if is_qs_running:
        fifo_path = os.path.join(rundir, f"prompt_{os.getpid()}_{int(time.time()*1000)}.fifo")
        try:
            if os.path.exists(fifo_path):
                os.remove(fifo_path)
            os.mkfifo(fifo_path, 0o600)

            # Trigger quickshell IPC promptInput
            ipc_cmd = [
                "quickshell", "ipc", "-p", os.path.expanduser("~/.config/quickshell"),
                "call", "shell", "promptInput",
                fifo_path, title, prompt, placeholder, default_value, icon
            ]
            subprocess.Popen(ipc_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            # Read result from FIFO
            with open(fifo_path, "r", encoding="utf-8") as f:
                val = f.read().strip()

            try:
                os.remove(fifo_path)
            except Exception:
                pass

            if val:
                return val
            return None
        except Exception:
            if os.path.exists(fifo_path):
                try: os.remove(fifo_path)
                except Exception: pass

    # Fallback to Rofi
    return prompt_rofi(prompt or title, placeholder=default_value or placeholder)


def reload_quickshell():
    """Reloads running quickshell daemon safely."""
    try:
        res = subprocess.run(["systemctl", "--user", "is-active", "quickshell.service"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode == 0:
            subprocess.Popen(["systemctl", "--user", "restart", "quickshell"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
    except Exception:
        pass

    launch_script = os.path.expanduser("~/.config/quickshell/launch.sh")
    if os.path.exists(launch_script):
        subprocess.Popen(["setsid", "nohup", launch_script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def install_plugin(repo_url):
    """Installs a plugin via omarchy plugin add with full environment setup and notifications."""
    repo_url = repo_url.strip()
    if not repo_url:
        return False

    # Expand GitHub shorthand 'user/repo'
    if "/" in repo_url and not repo_url.startswith("http://") and not repo_url.startswith("https://") and not repo_url.startswith("git@"):
        repo_url = f"https://github.com/{repo_url}.git"

    omarchy_bin = os.path.expanduser("~/.local/bin/omarchy")
    if not os.path.exists(omarchy_bin):
        omarchy_bin = "omarchy"

    env = os.environ.copy()
    env["PATH"] = f"{os.path.expanduser('~/.local/bin')}:/usr/local/bin:/usr/bin:/bin:" + env.get("PATH", "")

    try:
        # Notify progress
        repo_name = os.path.splitext(os.path.basename(repo_url.rstrip("/")))[0]
        try:
            subprocess.Popen([
                "notify-send",
                "Installing Plugin",
                f"Cloning and installing {repo_name}...",
                "-i", "preferences-plugin-symbolic"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

        proc = subprocess.run(
            [omarchy_bin, "plugin", "add", repo_url, "--enable"],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=120
        )

        if proc.returncode == 0:
            reload_quickshell()
            try:
                subprocess.Popen([
                    "notify-send",
                    "Plugin Installed",
                    f"✓ Plugin '{repo_name}' is installed and active.",
                    "-i", "preferences-plugin-symbolic"
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
            return True
        else:
            err_msg = (proc.stderr or proc.stdout or "Installation failed").strip()
            # Clean first meaningful line
            err_line = err_msg.splitlines()[-1] if err_msg else "Unknown error"
            try:
                subprocess.Popen([
                    "notify-send",
                    "Plugin Install Failed",
                    err_line[:120],
                    "-i", "dialog-error-symbolic"
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
            return False
    except subprocess.TimeoutExpired:
        try:
            subprocess.Popen([
                "notify-send",
                "Plugin Install Error",
                "Installation timed out after 120 seconds.",
                "-i", "dialog-error-symbolic"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        return False
    except Exception as e:
        try:
            subprocess.Popen([
                "notify-send",
                "Plugin Install Error",
                str(e)[:120],
                "-i", "dialog-error-symbolic"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        return False


def install_plugin_interactive():
    """Prompts for git repository URL or user/repo via Quickshell native dialog or Rofi and installs it."""
    url = prompt_quickshell(
        title="Install Omarchy Plugin",
        prompt="Enter Git repository URL or GitHub user/repo path:",
        placeholder="e.g. author/plugin or https://github.com/...",
        icon="󰏗"
    )
    if not url:
        return None
    return install_plugin(url)


def remove_plugin_interactive():
    """Interactive removal of an Omarchy plugin using native Quickshell UI with Rofi fallback."""
    is_qs_running = False
    try:
        res = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "quickshell"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        is_qs_running = res.returncode == 0
    except Exception:
        pass

    if is_qs_running:
        subprocess.Popen([
            "quickshell", "ipc", "-p", os.path.expanduser("~/.config/quickshell"),
            "call", "shell", "removePlugins"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    plugins = list_plugins()
    if not plugins:
        cmd = [
            "rofi",
            "-dmenu",
            "-i",
            "-p", "Notice",
            "-theme", RASI_THEME
        ]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        p.communicate(input="No installed Omarchy plugins found\0icon\x1fdialog-information-symbolic\n")
        return None

    lines = [".. Cancel\0icon\x1fgo-previous-symbolic"]
    for p in plugins:
        status = "Active" if p.get("enabled") else "Installed"
        lines.append(f"{p['name']} ({status})\0icon\x1f{p['icon']}\x1fmeta\x1f{p['dir']} {p.get('id', '')}")

    rofi_input = "\n".join(lines) + "\n"
    cmd = [
        "rofi",
        "-dmenu",
        "-i",
        "-show-icons",
        "-p", "Remove Plugin..",
        "-theme", RASI_THEME
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, _ = p.communicate(input=rofi_input)

    if not out or not out.strip() or out.strip() == ".. Cancel":
        return None

    selected = out.strip()
    target_dir = None
    target_name = None
    for p in plugins:
        status = "Active" if p.get("enabled") else "Installed"
        if f"{p['name']} ({status})" == selected or p["name"] == selected or p["dir"] == selected:
            target_dir = p["dir"]
            target_name = p["name"]
            break

    if target_dir:
        omarchy_bin = os.path.expanduser("~/.local/bin/omarchy")
        env = os.environ.copy()
        env["PATH"] = f"{os.path.expanduser('~/.local/bin')}:/usr/local/bin:/usr/bin:/bin:" + env.get("PATH", "")
        subprocess.run([omarchy_bin, "plugin", "remove", target_dir], env=env)
        reload_quickshell()
        try:
            subprocess.Popen([
                "notify-send",
                "Plugin Removed",
                f"Removed plugin '{target_name or target_dir}'",
                "-i", "user-trash-symbolic"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        return True
    return False


def launch_plugin(plugin):
    """Activates or toggles an installed plugin."""
    if isinstance(plugin, str):
        plugins = list_plugins()
        matched = None
        for p in plugins:
            if p["dir"] == plugin or p["id"] == plugin or p["name"].lower() == plugin.lower():
                matched = p
                break
        if not matched:
            return
        plugin = matched

    exec_cmd = plugin.get("exec")
    plugin_dir = plugin.get("dir", "")

    if exec_cmd:
        if "ledge" in exec_cmd or "ledge" in plugin_dir:
            subprocess.Popen([exec_cmd, "toggle"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        else:
            subprocess.Popen([exec_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return

    subprocess.Popen(["xdg-open", plugin.get("path", PLUGINS_DIR)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_plugins_dir():
    """Opens the quickshell plugins folder."""
    subprocess.Popen(["xdg-open", PLUGINS_DIR], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd in ["install", "add", "interactive"]:
            install_plugin_interactive()
        elif cmd in ["remove", "uninstall", "delete"]:
            remove_plugin_interactive()
        elif cmd == "open":
            open_plugins_dir()
        elif cmd == "list":
            print(json.dumps(list_plugins(), indent=2))
        elif cmd == "launch" and len(sys.argv) > 2:
            launch_plugin(sys.argv[2])
        else:
            print(json.dumps(list_plugins()))
    else:
        print(json.dumps(list_plugins()))
