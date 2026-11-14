// Session actions (lock / logout / power).
pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    function lock() {
        Quickshell.execDetached(["/home/Krish/.config/hypr/scripts/lock.sh"]);
    }

    function logout() {
        Quickshell.execDetached(["/home/Krish/.config/hypr/scripts/logout.sh"]);
    }

    function suspend() {
        Quickshell.execDetached(["/home/Krish/.config/hypr/scripts/suspend.sh"]);
    }

    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }

    function shutdown() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function rebootToFirmware() {
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }

    function launchTaskManager() {
        Quickshell.execDetached(["ghostty", "--title=btop", "-e", "btop"]);
    }

    function taskManager() { launchTaskManager(); }
    function poweroff() { shutdown(); }
}
