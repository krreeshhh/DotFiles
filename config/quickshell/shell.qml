//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "popups"

ShellRoot {
    id: root

    signal showOsd(string type, int val, bool muted)

    Variants {
        model: Quickshell.screens

        Bar {
            onToggleQuickSettings: {
                wifiMenu.closeImmediate();
                bluetoothMenu.closeImmediate();
                appLauncher.closeImmediate();
                controlCenter.toggle();
            }
            onToggleWifi: {
                controlCenter.closeImmediate();
                bluetoothMenu.closeImmediate();
                appLauncher.closeImmediate();
                wifiMenu.toggle();
            }
            onToggleBluetooth: {
                controlCenter.closeImmediate();
                wifiMenu.closeImmediate();
                appLauncher.closeImmediate();
                bluetoothMenu.toggle();
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Osd {
            Connections {
                target: root
                function onShowOsd(type, val, muted) {
                    trigger(type, val, muted);
                }
            }
        }
    }

    ControlCenter {
        id: controlCenter
        onOpenWifi: {
            controlCenter.closeImmediate();
            wifiMenu.openMenu();
        }
        onOpenBluetooth: {
            controlCenter.closeImmediate();
            bluetoothMenu.openMenu();
        }
    }

    WifiMenu {
        id: wifiMenu
    }

    BluetoothMenu {
        id: bluetoothMenu
    }

    AppLauncher {
        id: appLauncher
    }

    AuthDialog {
        id: authDialog
    }

    PromptDialog {
        id: promptDialog
    }

    IpcHandler {
        target: "shell"

        function promptInput(fifo: string, title: string, prompt: string, placeholder: string, defaultValue: string, icon: string): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.closeImmediate();
            authDialog.closeImmediate();
            promptDialog.openPrompt(fifo, title, prompt, placeholder, defaultValue, icon);
        }

        function closePrompt(): void {
            promptDialog.closeImmediate();
        }

        function promptAuth(fifo: string, prompt: string): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.closeImmediate();
            promptDialog.closeImmediate();
            authDialog.openAuth(fifo, prompt);
        }

        function closeAuth(): void {
            authDialog.closeImmediate();
        }

        function toggleControlCenter(): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            appLauncher.closeImmediate();
            controlCenter.toggle();
        }

        function toggleWifi(): void {
            controlCenter.closeImmediate();
            bluetoothMenu.closeImmediate();
            appLauncher.closeImmediate();
            wifiMenu.toggle();
        }

        function toggleBluetooth(): void {
            controlCenter.closeImmediate();
            wifiMenu.closeImmediate();
            appLauncher.closeImmediate();
            bluetoothMenu.toggle();
        }

        function toggleAppLauncher(): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.toggle();
        }

        function openAppLauncher(view: string): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.openMenu(view);
        }

        function removePlugins(): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.openMenu("remove_plugins");
        }

        function removeWebApps(): void {
            wifiMenu.closeImmediate();
            bluetoothMenu.closeImmediate();
            controlCenter.closeImmediate();
            appLauncher.openMenu("remove_webapps");
        }

        function closeAppLauncher(): void {
            appLauncher.closeMenu();
        }

        function reloadTheme(): void {
            Theme.reloadColors();
        }
    }

    IpcHandler {
        target: "osd"

        function show(type: string, value: int, muted: bool): void {
            root.showOsd(type, value, muted);
        }

        function brightness(value: int): void {
            root.showOsd("brightness", value, false);
        }

        function volume(value: int, muted: bool): void {
            root.showOsd("volume", value, muted);
        }
    }
}
