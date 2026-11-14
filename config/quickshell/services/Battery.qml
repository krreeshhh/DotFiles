// Battery state via UPower.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: !!device && device.isPresent
    readonly property real percentage: device?.percentage ?? 1
    readonly property var chargeState: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool isCharging: chargeState === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: isCharging || chargeState === UPowerDeviceState.FullyCharged || (device?.changeRate ?? 0) > 0
    readonly property bool isLow: percentage <= 0.15
    readonly property bool isCritical: percentage <= 0.05

    readonly property string timeRemaining: {
        if (!device) return "";
        const s = isCharging ? device.timeToFull : device.timeToEmpty;
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
