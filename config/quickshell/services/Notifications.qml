// Notification server + simple unread tracking.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    property int unread: 0
    property bool silent: false

    readonly property var list: server.trackedNotifications.values

    function markAllRead() {
        unread = 0;
    }

    function dismiss(notification) {
        try { notification.dismiss(); } catch (e) {}
    }

    function dismissAll() {
        for (const n of list) dismiss(n);
        unread = 0;
    }

    function toggleSilent() {
        silent = !silent;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false

        onNotification: (notification) => {
            notification.tracked = true;
            root.unread += 1;
        }
    }
}
