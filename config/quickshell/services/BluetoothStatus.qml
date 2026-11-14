// Bluetooth adapter/device state.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)
    readonly property int connectedCount: Bluetooth.devices.values.filter(d => d.connected).length

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }

    function setDiscovering(v) {
        if (adapter) adapter.discovering = v;
    }
}
