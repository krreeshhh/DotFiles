//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
import QtQuick
import Quickshell
import Quickshell.Io
import "popups"

// Launcher/auth host. The Dotfiles shell owns the bar and
// sidebars; this default Quickshell instance keeps the previous app launcher
// and the graphical auth/prompt dialogs (used by the sudo askpass helper).
ShellRoot {
    id: root

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
            appLauncher.closeImmediate();
            authDialog.closeImmediate();
            promptDialog.openPrompt(fifo, title, prompt, placeholder, defaultValue, icon);
        }

        function closePrompt(): void {
            promptDialog.closeImmediate();
        }

        function promptAuth(fifo: string, prompt: string): void {
            appLauncher.closeImmediate();
            promptDialog.closeImmediate();
            authDialog.openAuth(fifo, prompt);
        }

        function closeAuth(): void {
            authDialog.closeImmediate();
        }

        function toggleAppLauncher(): void {
            appLauncher.toggle();
        }

        function openAppLauncher(view: string): void {
            appLauncher.openMenu(view);
        }

        function searchAppLauncher(query: string): void {
            appLauncher.setSearch(query);
        }

        function selectAppLauncherIndex(idx: int): void {
            appLauncher.selectIndex(idx);
        }

        function closeAppLauncher(): void {
            appLauncher.closeMenu();
        }

        function closeAppLauncherImmediate(): void {
            appLauncher.closeImmediate();
        }

        function removeWebApps(): void {
            appLauncher.openMenu("remove_webapps");
        }

        function reloadTheme(): void {
            Theme.reloadColors();
        }
    }
}
