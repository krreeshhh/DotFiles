// Shared Hyprland focus grab for dismissable surfaces (sidebar, launcher, popups).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    function addPersistent(window) {
        if (!window) return;
        if (root.persistent.indexOf(window) === -1)
            root.persistent = root.persistent.concat([window]);
    }

    function removePersistent(window) {
        root.persistent = root.persistent.filter(w => w !== window);
    }

    function addDismissable(window) {
        if (!window) return;
        if (root.dismissable.indexOf(window) === -1)
            root.dismissable = root.dismissable.concat([window]);
    }

    function removeDismissable(window) {
        root.dismissable = root.dismissable.filter(w => w !== window);
    }

    // Legacy API used by the previous popups.
    function addDismissableItem(item) { addDismissable(item); }
    function removeDismissableItem(item) { removeDismissable(item); }
    function dismissSurface() { dismiss(); }

    property HyprlandFocusGrab grab: HyprlandFocusGrab {
        windows: [...root.dismissable, ...root.persistent]
        active: root.dismissable.length > 0
        onCleared: root.dismiss()
    }
}
