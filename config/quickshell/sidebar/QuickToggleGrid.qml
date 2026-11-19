import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../lib"

GridLayout {
    id: root
    columns: 4
    rowSpacing: 6
    columnSpacing: 6

    QuickToggleButton {
        span: 2
        iconName: Network.materialSymbol
        label: Network.wifiEnabled ? "Wi-Fi" : "Wi-Fi off"
        active: Network.wifiEnabled
        onClicked: Network.toggleWifi()
    }

    QuickToggleButton {
        span: 2
        iconName: BluetoothStatus.connected ? "bluetooth_connected"
            : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
        label: BluetoothStatus.connected ? "Connected" : BluetoothStatus.enabled ? "Bluetooth" : "Off"
        active: BluetoothStatus.enabled
        onClicked: BluetoothStatus.toggle()
    }

    QuickToggleButton {
        span: 1
        iconName: Audio.micMuted ? "mic_off" : "mic"
        label: ""
        active: !Audio.micMuted
        onClicked: Audio.toggleMicMute()
    }

    QuickToggleButton {
        span: 1
        iconName: Notifications.silent ? "notifications_off" : "notifications"
        label: ""
        active: !Notifications.silent
        onClicked: Notifications.toggleSilent()
    }

    QuickToggleButton {
        span: 2
        iconName: Audio.muted ? "volume_off" : "volume_up"
        label: Audio.muted ? "Muted" : "Audio"
        active: !Audio.muted
        onClicked: Audio.toggleMute()
    }

    QuickToggleButton {
        span: 2
        iconName: "coffee"
        label: "Idle inhibitor"
        active: GlobalStates.caffeineActive
        onClicked: {
            Quickshell.execDetached(["/home/Krish/.config/hypr/scripts/caffeine.sh", "toggle"]);
            GlobalStates.caffeineActive = !GlobalStates.caffeineActive;
        }
    }

    QuickToggleButton {
        span: 2
        iconName: "screenshot_region"
        label: "Screenshot"
        active: false
        onClicked: Quickshell.execDetached(["/home/Krish/.config/hypr/scripts/screenshot.sh"])
    }

    QuickToggleButton {
        span: 4
        iconName: PowerProfile.isBattery ? "energy_savings_leaf" : "local_fire_department"
        label: PowerProfile.isBattery ? "Power: Battery Saver" : "Power: Performance"
        active: PowerProfile.isBattery
        onClicked: PowerProfile.toggle()
    }
}
