import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

QtObject {
    id: theme

    // Material You dynamic colors
    property color primary: "#e183c2"
    property color colOnPrimary: "#121214"
    property color primaryContainer: "#401b34"
    property color secondary: "#d8a5ca"
    property color background: "#130f12"
    property color surface: "#1f181d"
    property color surfaceVariant: "#2c2028"
    property color surfaceSelected: "#401b34"
    property color colOnSurface: "#ffffff"
    property color colOnSurfaceVariant: "#a5a5aa"
    property color outline: "#412f3b"
    property color outlineSubtle: "#25252a"
    property color colorError: "#ff6b6b"

    // Bar & Popup glass theme (auto-binds to dynamic colors)
    property color barBackground: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.45)
    property color barBorder: Qt.rgba(1, 1, 1, 0.04)

    property color popupSurface: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.55)
    property color popupSurfaceVariant: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.40)
    property color popupSurfaceSelected: Qt.rgba(theme.surfaceSelected.r, theme.surfaceSelected.g, theme.surfaceSelected.b, 0.60)
    property color popupBorder: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.30)

    // Dotfiles-inspired layer system (all derived from the dynamic colors above)
    property color colLayer0: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.55)
    property color colLayer0Border: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.35)
    property color colLayer1: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.42)
    property color colLayer1Hover: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.55)
    property color colLayer1Active: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.68)
    property color colLayer1Border: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.50)
    property color colLayer2: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.35)
    property color colLayer2Hover: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.50)
    property color colLayer2Border: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.45)
    property color colOnLayer0: theme.colOnSurface
    property color colOnLayer1: theme.colOnSurface
    property color colSubtext: theme.colOnSurfaceVariant
    property color colPrimaryContainer: theme.primaryContainer
    property color colPrimaryContainerActive: Qt.lighter(theme.primaryContainer, 1.3)
    property color colOnPrimaryContainer: Qt.lighter(theme.primaryContainer, 2.1)
    property color colSecondaryContainer: Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.26)
    property color colOnSecondaryContainer: theme.secondary
    property color colErrorContainer: Qt.rgba(theme.colorError.r, theme.colorError.g, theme.colorError.b, 0.26)
    property color colOnErrorContainer: theme.colorError
    property color colOutline: theme.outline
    property color colOutlineVariant: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.6)
    property real roundingNormal: 12
    property real roundingLarge: 16
    property real roundingFull: 1000

    // Typography
    property string fontFamily: "JetBrainsMono Nerd Font"

    // Process to dynamically read generated Material You colors
    property var themeProc: Process {
        command: ["python3", "-c", "import json, os; p = os.path.expanduser('~/.config/DotFiles/theme/colors.json'); d = json.load(open(p))['colors']; print('|'.join([d.get(k,'') for k in ['primary','on_primary','primary_container','secondary','background','surface','surface_variant','surface_selected','on_surface','on_surface_variant','outline','outline_subtle','error']]))"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;
                var parts = line.split("|");
                if (parts.length >= 13) {
                    if (parts[0]) theme.primary = parts[0];
                    if (parts[1]) theme.colOnPrimary = parts[1];
                    if (parts[2]) theme.primaryContainer = parts[2];
                    if (parts[3]) theme.secondary = parts[3];
                    if (parts[4]) theme.background = parts[4];
                    if (parts[5]) theme.surface = parts[5];
                    if (parts[6]) theme.surfaceVariant = parts[6];
                    if (parts[7]) theme.surfaceSelected = parts[7];
                    if (parts[8]) theme.colOnSurface = parts[8];
                    if (parts[9]) theme.colOnSurfaceVariant = parts[9];
                    if (parts[10]) theme.outline = parts[10];
                    if (parts[11]) theme.outlineSubtle = parts[11];
                    if (parts[12]) theme.colorError = parts[12];
                }
            }
        }
    }

    function reloadColors() {
        themeProc.running = true;
    }

    property var pollTimer: Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.reloadColors()
    }

    Component.onCompleted: {
        reloadColors();
    }
}
