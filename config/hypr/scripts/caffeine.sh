#!/usr/bin/env bash
# ==========================================================
# caffeine.sh - Idle and Sleep Inhibitor for Hyprland & Linux
# ==========================================================
set -euo pipefail

PIDFILE="/tmp/caffeine_inhibit.pid"

is_active() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid="$(cat "$PIDFILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    if pgrep -f "systemd-inhibit.*--who=Caffeine" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

enable_caffeine() {
    if is_active; then
        return 0
    fi

    # Holds a hard block lock on idle, sleep, lid-switch, and suspend-key
    systemd-inhibit --mode=block --what=idle:sleep:handle-lid-switch:handle-suspend-key --who="Caffeine" --why="Caffeine active - stay awake on lid close and idle" sleep infinity >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDFILE"

    # Pause idle monitors if running
    pkill -STOP -x hypridle 2>/dev/null || true
    pkill -STOP -x swayidle 2>/dev/null || true

    notify-send -a "Caffeine" -i "caffeine" "Caffeine Active" "System will stay 100% awake (even when idle or lid closed) ☕" -t 2500 2>/dev/null || true
}

disable_caffeine() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid="$(cat "$PIDFILE" 2>/dev/null || true)"
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PIDFILE"
    fi
    pkill -f "systemd-inhibit.*--who=Caffeine" 2>/dev/null || true

    # Resume idle monitors
    pkill -CONT -x hypridle 2>/dev/null || true
    pkill -CONT -x swayidle 2>/dev/null || true

    notify-send -a "Caffeine" -i "caffeine" "Caffeine Deactivated" "Normal sleep & idle timers restored 󰒲" -t 2000 2>/dev/null || true
}

toggle_caffeine() {
    if is_active; then
        disable_caffeine
        echo "inactive"
    else
        enable_caffeine
        echo "active"
    fi
}

case "${1:-status}" in
    on|enable)
        enable_caffeine
        echo "active"
        ;;
    off|disable)
        disable_caffeine
        echo "inactive"
        ;;
    toggle)
        toggle_caffeine
        ;;
    status)
        if is_active; then
            echo "active"
        else
            echo "inactive"
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        exit 1
        ;;
esac
