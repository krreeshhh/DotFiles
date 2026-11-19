import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    name: Translation.tr("Notifications")
    statusText: (!Notifications.silent) ? Translation.tr("Show") : Translation.tr("Silent")
    toggled: !Notifications.silent
    icon: (!Notifications.silent) ? "notifications_active" : "notifications_paused"
    tooltipText: (!Notifications.silent)
        ? Translation.tr("Notifications: Show (Click for Silent/DND)")
        : Translation.tr("Notifications: Silent/DND (Click to Show)")

    mainAction: () => {
        Notifications.silent = !Notifications.silent;
        if (!Notifications.silent) {
            Quickshell.execDetached(["notify-send", "-a", "Notifications", "-u", "low", "-i", "notifications", "Notifications: Show", "Notification popups and alerts are enabled."]);
        }
    }

    altAction: () => {
        Notifications.discardAllNotifications();
    }
}
