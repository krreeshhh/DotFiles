#!/usr/bin/env python3
"""
Web App Manager for Desktop
Creates and removes standalone Web Applications (PWAs) that run via browser --app mode,
complete with auto-fetched high-res icons and desktop category integration.
"""

import os
import sys
import re
import urllib.request
import urllib.parse
import subprocess
import glob

ICONS_DIR = os.path.expanduser("~/.local/share/icons/webapps")
DESKTOP_DIR = os.path.expanduser("~/.local/share/applications")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RASI_THEME = os.path.join(SCRIPT_DIR, "launcher.rasi")

os.makedirs(ICONS_DIR, exist_ok=True)
os.makedirs(DESKTOP_DIR, exist_ok=True)

def find_browser_cmd():
    for cmd in ["brave-origin", "brave", "brave-browser", "chromium", "google-chrome-stable", "google-chrome", "firefox"]:
        path = subprocess.run(["which", cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
        if path:
            return cmd
    return "brave-origin"

def sanitize_id(name):
    return re.sub(r'[^a-zA-Z0-9_-]', '_', name.lower().strip())

def extract_domain(url):
    if not url.startswith("http://") and not url.startswith("https://"):
        url = "https://" + url
    parsed = urllib.parse.urlparse(url)
    return parsed.netloc or parsed.path.split('/')[0]

def download_icon(target_url, app_id):
    import io
    from PIL import Image

    if not target_url.startswith("http://") and not target_url.startswith("https://"):
        target_url = "https://" + target_url
        
    parsed = urllib.parse.urlparse(target_url)
    domain = parsed.netloc or parsed.path.split("/")[0]
    base_url = f"{parsed.scheme}://{domain}"
    icon_path = os.path.join(ICONS_DIR, f"{app_id}.png")
    
    candidates = []
    
    # 1. Google High-Res Favicon V2 API (128px)
    candidates.append(f"https://t3.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url={urllib.parse.quote(target_url)}&size=128")
    
    # 2. Scrape website HTML for apple-touch-icon (high-res retina icon) and standard icons
    try:
        req = urllib.request.Request(
            target_url,
            headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"}
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
            
            # Extract apple-touch-icon (highest resolution 180x180+)
            touch_icons = re.findall(r"<link[^>]+rel=[\x27\"]apple-touch-icon[\x27\"][^>]+href=[\x27\"]([^\x27\"]+)[\x27\"]", html, re.I)
            touch_icons += re.findall(r"<link[^>]+href=[\x27\"]([^\x27\"]+)[\x27\"][^>]+rel=[\x27\"]apple-touch-icon[\x27\"]", html, re.I)
            for t in touch_icons:
                candidates.insert(0, urllib.parse.urljoin(target_url, t))
                
            # Extract manifest or standard icons
            std_icons = re.findall(r"<link[^>]+rel=[\x27\"](?:shortcut )?icon[\x27\"][^>]+href=[\x27\"]([^\x27\"]+)[\x27\"]", html, re.I)
            std_icons += re.findall(r"<link[^>]+href=[\x27\"]([^\x27\"]+)[\x27\"][^>]+rel=[\x27\"](?:shortcut )?icon[\x27\"]", html, re.I)
            for s in std_icons:
                candidates.append(urllib.parse.urljoin(target_url, s))
    except Exception:
        pass
        
    # 3. DuckDuckGo and Root favicon fallbacks
    candidates.append(f"https://icons.duckduckgo.com/ip3/{domain}.ico")
    candidates.append(f"{base_url}/favicon.ico")
    
    for u in candidates:
        try:
            req = urllib.request.Request(
                u,
                headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}
            )
            with urllib.request.urlopen(req, timeout=4) as resp:
                data = resp.read()
                if len(data) > 150:
                    img = Image.open(io.BytesIO(data))
                    # Convert any format (WebP, ICO, JPEG, GIF) to standard 32-bit RGBA PNG
                    rgba_img = img.convert("RGBA")
                    # If tiny (less than 48px), keep it clean; if large, resize gracefully
                    if rgba_img.width > 256 or rgba_img.height > 256:
                        rgba_img = rgba_img.resize((128, 128), Image.Resampling.LANCZOS)
                    rgba_img.save(icon_path, "PNG")
                    return icon_path
        except Exception:
            continue
            
    return "web-browser"

def auto_detect_category(name, url):
    """
    Automatically infers the most appropriate category
    based on app name, URL domain, and service signatures.
    """
    text = f"{name} {url}".lower()
    
    # 1. AI & Utilities
    if any(k in text for k in [
        "chatgpt", "openai", "claude.ai", "anthropic", "perplexity", "deepseek", "gemini.google",
        "copilot.microsoft", "translate.google", "deepl", "wolframalpha", "speedtest",
        "maps.google", "google.com/maps", "calculator", "weather", "convert", "tool", "ai"
    ]):
        return "Utilities"
        
    # 2. Music & Audio
    if any(k in text for k in [
        "spotify", "soundcloud", "music.youtube", "apple.com/music", "deezer", "bandcamp",
        "tidal.com", "mixcloud", "pandora.com", "audiomack", "radio", "podcast", "music",
        "audio", "beatport", "last.fm", "song"
    ]):
        return "Music & Audio"
        
    # 3. Development
    if any(k in text for k in [
        "github", "gitlab", "bitbucket", "stackoverflow", "stackexchange", "codesandbox",
        "replit", "leetcode", "hackerrank", "codepen", "vercel", "netlify", "supabase",
        "cloudflare", "aws.amazon", "console.cloud.google", "portal.azure", "huggingface",
        "dev.to", "npmjs", "pypi", "crates.io", "docker", "postman", "swagger", "sentry",
        "localhost", "127.0.0.1", "code", "dev", "git", "api", "ide", "repository"
    ]):
        return "Development"
        
    # 4. Graphics & Media / Video
    if any(k in text for k in [
        "youtube", "youtu.be", "netflix", "twitch", "primevideo", "hulu", "disneyplus",
        "vimeo", "crunchyroll", "figma", "canva", "photopea", "dribbble", "behance",
        "artstation", "pixiv", "midjourney", "pinterest", "imgur", "unsplash", "video",
        "stream", "movie", "watch", "anime", "design", "drawing", "photo", "art", "cinema"
    ]):
        return "Graphics & Media"
        
    # 5. Office & Docs / Productivity
    if any(k in text for k in [
        "notion", "docs.google", "sheets.google", "slides.google", "drive.google",
        "office.com", "office365", "overleaf", "miro.com", "trello", "asana", "clickup",
        "jira", "atlassian", "confluence", "linear.app", "obsidian", "keep.google",
        "evernote", "todoist", "calendar.google", "airtable", "coda.io", "document",
        "spreadsheet", "workspace", "notes", "wiki", "pdf", "docs"
    ]):
        return "Office & Docs"
        
    # 6. Messaging & Social
    if any(k in text for k in [
        "discord", "telegram", "t.me", "web.whatsapp", "whatsapp", "slack", "signal",
        "messenger", "teams.microsoft", "matrix", "element.io", "twitter", "x.com",
        "mastodon", "threads.net", "reddit", "instagram", "facebook", "linkedin",
        "gmail", "mail.google", "outlook", "proton.me", "protonmail", "chat", "message",
        "inbox", "social"
    ]):
        return "Messaging"
        
    # Fallback to Browser category
    return "Browser"

def create_webapp(name, url, category=None, custom_icon=None):
    if not url.startswith("http://") and not url.startswith("https://"):
        url = "https://" + url
        
    app_id = sanitize_id(name)
    domain = extract_domain(url)
    
    if not category or category == "auto":
        category = auto_detect_category(name, url)
    
    if custom_icon and os.path.exists(custom_icon):
        icon_path = custom_icon
    else:
        icon_path = download_icon(url, app_id)
        
    browser_bin = find_browser_cmd()
    
    cat_map = {
        "Development": "Development;IDE;TextEditor;",
        "Browser": "Network;WebBrowser;",
        "Music & Audio": "AudioVideo;Audio;Music;Player;",
        "Messaging": "Network;Chat;InstantMessaging;",
        "Graphics & Media": "Graphics;2DGraphics;Viewer;",
        "Games": "Game;",
        "Office & Docs": "Office;",
        "Utilities": "Utility;",
        "System & Settings": "System;Settings;"
    }
    xdg_cat = cat_map.get(category, "Network;WebBrowser;Utility;")
    
    if "firefox" in browser_bin:
        exec_cmd = f"{browser_bin} --new-window {url}"
    else:
        exec_cmd = f"{browser_bin} --app={url}"
        
    desktop_content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={name}
Comment={name} (Web Application)
Exec={exec_cmd}
Icon={icon_path}
Terminal=false
StartupWMClass={domain}
Categories={xdg_cat}
X-WebApp=true
X-WebApp-URL={url}
X-WebApp-Category={category}
"""
    desktop_file = os.path.join(DESKTOP_DIR, f"webapp-{app_id}.desktop")
    with open(desktop_file, "w", encoding="utf-8") as f:
        f.write(desktop_content)
        
    try:
        subprocess.Popen([
            "notify-send",
            "Web App Installed",
            f"{name} is now ready in your launcher",
            "-i", icon_path
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
        
    return desktop_file

def list_webapps():
    webapps = []
    for f in glob.glob(os.path.join(DESKTOP_DIR, "webapp-*.desktop")):
        name, icon, url, cat = "", "", "", ""
        try:
            with open(f, "r", encoding="utf-8", errors="ignore") as file:
                for line in file:
                    line = line.strip()
                    if line.startswith("Name="):
                        name = line.split("=", 1)[1]
                    elif line.startswith("Icon="):
                        icon = line.split("=", 1)[1]
                    elif line.startswith("X-WebApp-URL="):
                        url = line.split("=", 1)[1]
                    elif line.startswith("X-WebApp-Category="):
                        cat = line.split("=", 1)[1]
            if name and url:
                webapps.append({
                    "name": name,
                    "icon": icon or "web-browser",
                    "file": f,
                    "url": url,
                    "category": cat
                })
        except Exception:
            continue
    webapps.sort(key=lambda x: x["name"].lower())
    return webapps

def remove_webapp_file(desktop_path):
    try:
        app_id = os.path.splitext(os.path.basename(desktop_path))[0].replace("webapp-", "")
        icon_path = os.path.join(ICONS_DIR, f"{app_id}.png")
        if os.path.exists(desktop_path):
            os.remove(desktop_path)
        if os.path.exists(icon_path):
            os.remove(icon_path)
        try:
            subprocess.Popen([
                "notify-send",
                "Web App Removed",
                f"Removed web app {app_id}",
                "-i", "user-trash-symbolic"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        return True
    except Exception:
        return False

def prompt_rofi(prompt, placeholder=""):
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


def prompt_quickshell(title="Create Web App", prompt="", placeholder="", default_value="", icon="󰖟"):
    """
    Shows native Quickshell PromptDialog if Quickshell is active.
    Falls back gracefully to Rofi.
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
        fifo_path = os.path.join(rundir, f"webapp_{os.getpid()}_{int(time.time()*1000)}.fifo")
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


def interactive_add_webapp():
    """
    Step 1: Get App Name
    Step 2: Get URL
    Automatically infers category, fetches high-res favicon, and generates the app!
    """
    # Step 1: App Name
    name = prompt_quickshell(
        title="Create Web App (PWA)",
        prompt="Enter a name for the web application:",
        placeholder="e.g. Notion, Linear, ChatGPT...",
        icon="󰖟"
    )
    if not name:
        return None

    # Step 2: URL
    url = prompt_quickshell(
        title=f"URL for {name}",
        prompt=f"Enter website URL for '{name}':",
        placeholder="https://",
        default_value="https://",
        icon="󰖟"
    )
    if not url or url == "https://":
        return None

    # Automatically categorize and create web app
    desktop_file = create_webapp(name, url, category=None)
    return desktop_file

def interactive_remove_webapp():
    """
    Shows list of existing web applications and removes the selected one.
    """
    is_qs_running = False
    try:
        res = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "quickshell"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        is_qs_running = res.returncode == 0
    except Exception:
        pass

    if is_qs_running:
        subprocess.Popen([
            "quickshell", "ipc", "-p", os.path.expanduser("~/.config/quickshell"),
            "call", "shell", "removeWebApps"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    webapps = list_webapps()
    if not webapps:
        # Show brief notice
        cmd = [
            "rofi",
            "-dmenu",
            "-i",
            "-p", "Notice",
            "-theme", RASI_THEME
        ]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        p.communicate(input="No installed Web Apps found\0icon\x1fdialog-information-symbolic\n")
        return None
        
    lines = [".. Cancel\0icon\x1fgo-previous-symbolic"]
    app_map = {}
    for app in webapps:
        label = f"{app['name']} ({app['category'] or 'Web'})"
        lines.append(f"{label}\0icon\x1f{app['icon']}")
        app_map[label] = app
        
    rofi_input = "\n".join(lines) + "\n"
    cmd = [
        "rofi",
        "-dmenu",
        "-i",
        "-show-icons",
        "-p", "Remove Web App..",
        "-theme", RASI_THEME
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, _ = p.communicate(input=rofi_input)
    
    if not out or not out.strip() or out.strip() == ".. Cancel":
        return None
        
    selected = out.strip()
    if selected in app_map:
        remove_webapp_file(app_map[selected]["file"])
        return selected
    return None

if __name__ == "__main__":
    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == "add" and len(sys.argv) >= 4:
            name = sys.argv[2]
            url = sys.argv[3]
            cat = sys.argv[4] if len(sys.argv) > 4 else "Browser"
            f = create_webapp(name, url, cat)
            print(f"Created webapp: {f}")
        elif action == "remove":
            if len(sys.argv) >= 3:
                name = sys.argv[2]
                res = remove_webapp_file(os.path.join(DESKTOP_DIR, f"webapp-{sanitize_id(name)}.desktop"))
                print("Removed" if res else "Not found")
            else:
                interactive_remove_webapp()
        elif action == "list":
            for app in list_webapps():
                print(f"{app['name']} -> {app['url']} [{app['category']}]")
        elif action == "interactive":
            interactive_add_webapp()
    else:
        interactive_add_webapp()
