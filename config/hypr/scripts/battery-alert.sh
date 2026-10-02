#!/usr/bin/env bash
# ==============================================================================
# battery-alert.sh - Battery Percentage Drop Notification Daemon
# ==============================================================================
# Alerts on every 5% battery reduction at and below 25%:
#   25% -> Low Battery Warning (normal)
#   20% -> Low Battery Warning (normal)
#   15% -> Power Low Alert (normal)
#   10% -> Critical Battery Alert (critical)
#    5% -> Urgent Battery Emergency (critical)
#
# Automatically resets when AC charger is plugged in or battery charges up.
# ==============================================================================

set -euo pipefail

# Find primary battery sysfs directory
find_battery() {
    for b in /sys/class/power_supply/BAT* /sys/class/power_supply/battery*; do
        if [ -d "$b" ] && [ -f "$b/capacity" ] && [ -f "$b/status" ]; then
            echo "$b"
            return 0
        fi
    done
    return 1
}

BAT_PATH="$(find_battery || true)"
if [ -z "$BAT_PATH" ]; then
    echo "No battery found on this system. Exiting battery monitor."
    exit 0
fi

# Track alert states (0 = not alerted yet, 1 = alerted)
NOTIFIED_25=0
NOTIFIED_20=0
NOTIFIED_15=0
NOTIFIED_10=0
NOTIFIED_5=0

LAST_STATUS=""

send_alert() {
    local level="$1"
    local title="$2"
    local msg="$3"
    local urgency="$4"
    local icon="$5"
    local sound="$6"

    # Send desktop notification via dunst
    notify-send -a "Battery" \
        -u "$urgency" \
        -i "$icon" \
        "$title" \
        "$msg" 2>/dev/null || true

    # Play alert sound if available
    if command -v canberra-gtk-play >/dev/null 2>&1; then
        canberra-gtk-play -i "$sound" 2>/dev/null &
    fi
}

check_battery() {
    local capacity status
    capacity="$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "100")"
    status="$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")"

    # State transitions: Charger plugged in / unplugged
    if [ -n "$LAST_STATUS" ] && [ "$status" != "$LAST_STATUS" ]; then
        if [ "$status" = "Charging" ]; then
            notify-send -a "Battery" -u low -i "battery-charging" "Charger Connected" "Battery is charging at ${capacity}%." 2>/dev/null || true
            if command -v canberra-gtk-play >/dev/null 2>&1; then
                canberra-gtk-play -i power-plug 2>/dev/null &
            fi
            # Reset all low-battery thresholds when charging begins
            NOTIFIED_25=0
            NOTIFIED_20=0
            NOTIFIED_15=0
            NOTIFIED_10=0
            NOTIFIED_5=0
        elif [ "$status" = "Discharging" ] && [ "$LAST_STATUS" = "Charging" ]; then
            notify-send -a "Battery" -u low -i "battery" "Charger Disconnected" "Running on battery at ${capacity}%." 2>/dev/null || true
            if command -v canberra-gtk-play >/dev/null 2>&1; then
                canberra-gtk-play -i power-unplug 2>/dev/null &
            fi
        fi
    fi
    LAST_STATUS="$status"

    # If charging or full, clear thresholds if battery rose above them + 2% hysteresis
    if [ "$status" != "Discharging" ]; then
        [ "$capacity" -gt 27 ] && NOTIFIED_25=0
        [ "$capacity" -gt 22 ] && NOTIFIED_20=0
        [ "$capacity" -gt 17 ] && NOTIFIED_15=0
        [ "$capacity" -gt 12 ] && NOTIFIED_10=0
        [ "$capacity" -gt 7 ]  && NOTIFIED_5=0
        return 0
    fi

    # Discharging alerts on every 5% reduction after/below 25%
    if [ "$capacity" -le 5 ]; then
        if [ "$NOTIFIED_5" -eq 0 ]; then
            send_alert 5 "Battery Urgent (5%)" "Battery is at ${capacity}%! Immediate shutdown imminent - connect charger now!" "critical" "battery-empty" "dialog-error"
            NOTIFIED_5=1
            NOTIFIED_10=1
            NOTIFIED_15=1
            NOTIFIED_20=1
            NOTIFIED_25=1
        fi
    elif [ "$capacity" -le 10 ]; then
        if [ "$NOTIFIED_10" -eq 0 ]; then
            send_alert 10 "Battery Critical (10%)" "Battery is down to ${capacity}%. Connect charger immediately to avoid shutdown." "critical" "battery-caution" "dialog-error"
            NOTIFIED_10=1
            NOTIFIED_15=1
            NOTIFIED_20=1
            NOTIFIED_25=1
        fi
    elif [ "$capacity" -le 15 ]; then
        if [ "$NOTIFIED_15" -eq 0 ]; then
            send_alert 15 "Battery Warning (15%)" "Battery is at ${capacity}%. Power is running low!" "normal" "battery-caution" "dialog-warning"
            NOTIFIED_15=1
            NOTIFIED_20=1
            NOTIFIED_25=1
        fi
    elif [ "$capacity" -le 20 ]; then
        if [ "$NOTIFIED_20" -eq 0 ]; then
            send_alert 20 "Battery Warning (20%)" "Battery has dropped to ${capacity}%. Please plug in your charger soon." "normal" "battery-caution" "dialog-warning"
            NOTIFIED_20=1
            NOTIFIED_25=1
        fi
    elif [ "$capacity" -le 25 ]; then
        if [ "$NOTIFIED_25" -eq 0 ]; then
            send_alert 25 "Battery Low (25%)" "Battery is at ${capacity}%. Consider plugging in your charger." "normal" "battery-caution" "dialog-warning"
            NOTIFIED_25=1
        fi
    else
        # Above 25%: Reset flags if capacity recovers (e.g. briefly plugged in)
        [ "$capacity" -gt 27 ] && NOTIFIED_25=0
        [ "$capacity" -gt 22 ] && NOTIFIED_20=0
        [ "$capacity" -gt 17 ] && NOTIFIED_15=0
        [ "$capacity" -gt 12 ] && NOTIFIED_10=0
        [ "$capacity" -gt 7 ]  && NOTIFIED_5=0
    fi
}

# Single check mode for testing
if [ "${1:-}" = "--check-once" ]; then
    check_battery
    echo "Battery check completed. (Device: $BAT_PATH, Capacity: $(cat "$BAT_PATH/capacity")%, Status: $(cat "$BAT_PATH/status"))"
    exit 0
fi

# Main monitoring loop (every 20 seconds)
while true; do
    check_battery
    sleep 20
done
