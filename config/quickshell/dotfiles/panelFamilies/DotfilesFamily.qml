import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.dotfiles.background
import qs.modules.dotfiles.bar
import qs.modules.dotfiles.dock
import qs.modules.dotfiles.lock
import qs.modules.dotfiles.mediaControls
import qs.modules.dotfiles.notificationPopup
import qs.modules.dotfiles.onScreenDisplay
import qs.modules.dotfiles.onScreenKeyboard
import qs.modules.dotfiles.regionSelector
import qs.modules.dotfiles.screenCorners
import qs.modules.dotfiles.screenTranslator
import qs.modules.dotfiles.sessionScreen
import qs.modules.dotfiles.sidebarRight
import qs.modules.dotfiles.overlay
import qs.modules.dotfiles.verticalBar

Scope {
    PanelLoader { extraCondition: !Config.options.bar.vertical; component: Bar {} }
    PanelLoader { component: Background {} }
    PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: ScreenTranslator {} }
    PanelLoader { component: SessionScreen {} }
    PanelLoader { component: SidebarRight {} }
    PanelLoader { extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
}
