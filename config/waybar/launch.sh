#!/usr/bin/env bash

systemctl --user stop waybar-app 2>/dev/null || true
killall -q waybar || true
while pgrep -x waybar >/dev/null; do sleep 0.1; done
systemd-run --user --unit=waybar-app waybar >/dev/null 2>&1 || waybar &
