#!/usr/bin/env bash
# Suspend Helper with Lockscreen Pre-activation

# Trigger screen lock
if ! pidof hyprlock >/dev/null 2>&1; then
    hyprlock &
    sleep 0.3
fi

# Put machine to sleep
systemctl suspend
