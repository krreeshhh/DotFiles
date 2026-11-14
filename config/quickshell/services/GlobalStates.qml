// Central UI state. One source of truth for every surface.
pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // Surfaces
    property bool barOpen: true
    property bool sidebarRightOpen: false
    property bool launcherOpen: false
    property bool sessionOpen: false
    property bool mediaControlsOpen: false
    property bool osdVolumeOpen: false
    property bool osdBrightnessOpen: false

    // System
    property bool screenLocked: false
    property bool superDown: false
    property bool caffeineActive: false
    property bool nightLightActive: false
    property string searchPrefix: ""

    function closeAll(except) {
        if (except !== "sidebar") sidebarRightOpen = false;
        if (except !== "launcher") launcherOpen = false;
        if (except !== "session") sessionOpen = false;
        if (except !== "media") mediaControlsOpen = false;
    }
}
