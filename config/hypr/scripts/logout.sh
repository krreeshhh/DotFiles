#!/usr/bin/env bash
# Logout Helper for Hyprland / SDDM

# Ensure current instance signature is present if running from subshell
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | grep -v '^\.' | head -n 1)
    export HYPRLAND_INSTANCE_SIGNATURE
fi

hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER"
