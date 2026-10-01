#!/usr/bin/env bash

# Rofi Wi-Fi Menu Script
# Scans and allows connecting to Wi-Fi networks

# Get list of Wi-Fi networks
WIFI_LIST=$(nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | sed 's/  */ /g' | sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" | sed "s/  //g" | sed "/--/d" | awk '!seen[$0]++')

# Add connection editor option at the top
CHOICE=$(echo -e "⚙️ Network Settings (GUI)\n🔄 Rescan Networks\n$WIFI_LIST" | uniq -u | rofi -dmenu -i -p "Wi-Fi Networks" -font "JetBrainsMono Nerd Font 10")

if [ -z "$CHOICE" ]; then
    exit 0
fi

if [ "$CHOICE" = "⚙️ Network Settings (GUI)" ]; then
    nm-connection-editor &
    exit 0
elif [ "$CHOICE" = "🔄 Rescan Networks" ]; then
    nmcli device wifi rescan
    exec "$0"
fi

# Extract chosen SSID (strip leading security icon)
SSID=$(echo "$CHOICE" | sed 's/^[] *//' | sed 's/^[ \t]*//')

if [ -n "$SSID" ]; then
    # Check if network is already known/saved
    SAVED=$(nmcli -g NAME connection show | grep -Fx "$SSID")
    if [ -n "$SAVED" ]; then
        nmcli connection up id "$SSID" && notify-send "Wi-Fi" "Connected to $SSID"
    else
        # Prompt for password
        PASS=$(rofi -dmenu -password -p "Password for $SSID" -font "JetBrainsMono Nerd Font 10")
        if [ -n "$PASS" ]; then
            nmcli device wifi connect "$SSID" password "$PASS" && notify-send "Wi-Fi" "Connected to $SSID" || notify-send "Wi-Fi" "Failed to connect to $SSID"
        fi
    fi
fi
