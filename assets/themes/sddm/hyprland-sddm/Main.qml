import "."
import QtQuick
import SddmComponents
import QtQuick.Effects
import QtMultimedia
import Qt.labs.folderlistmodel
import "components"

Item {
    id: root
    state: Config.lockScreenDisplay ? "lockState" : "loginState"

    // Load Red Hat typography bundled with the theme
    FontLoader {
        source: "fonts/redhat/RedHatDisplay-Regular.otf"
    }
    FontLoader {
        source: "fonts/redhat/RedHatDisplay-Medium.otf"
    }
    FontLoader {
        source: "fonts/redhat/RedHatDisplay-SemiBold.otf"
    }
    FontLoader {
        source: "fonts/redhat/RedHatDisplay-Bold.otf"
    }
    FontLoader {
        source: "fonts/redhat/RedHatDisplay-Black.otf"
    }

    TextConstants {
        id: textConstants
    }

    property bool capsLockOn: false
    property string activeWallpaperSource: ""

    function resolveSource(src) {
        if (!src || src.length === 0) return "backgrounds/default.jpg";
        var str = src.toString();
        if (str.indexOf("file://") === 0 || str.indexOf("/") === 0) {
            return str.indexOf("file://") === 0 ? str : ("file://" + str);
        }
        return "backgrounds/" + str;
    }

    FolderListModel {
        id: wallpaperFolderModel
        folder: {
            var dir = Config.wallpaperDirectory || "/home/Krish/.wallpaper";
            if (!dir || dir.length === 0) dir = "/home/Krish/.wallpaper";
            return dir.indexOf("file://") === 0 ? dir : ("file://" + dir);
        }
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        showDirs: false
        showDotAndDotDot: false
        onStatusChanged: {
            if (status === FolderListModel.Ready && count > 0) {
                if (Config.randomWallpaper && (!activeWallpaperSource || activeWallpaperSource.length === 0 || activeWallpaperSource.indexOf("backgrounds/") === 0)) {
                    pickRandomWallpaper();
                }
            }
        }
    }

    function pickRandomWallpaper() {
        if (wallpaperFolderModel.count > 0) {
            var randIndex = Math.floor(Math.random() * wallpaperFolderModel.count);
            var fileUrl = wallpaperFolderModel.get(randIndex, "fileUrl");
            if (fileUrl && fileUrl.toString().length > 0) {
                activeWallpaperSource = fileUrl.toString();
                console.log("[SilentSDDM] Selected random wallpaper:", activeWallpaperSource);
                return;
            }
        }
        activeWallpaperSource = resolveSource(Config.lockScreenBackground);
        console.log("[SilentSDDM] Fallback wallpaper:", activeWallpaperSource);
    }

    Timer {
        id: wallpaperCycleTimer
        interval: Config.wallpaperInterval > 0 ? (Config.wallpaperInterval * 1000) : 0
        repeat: true
        running: Config.randomWallpaper && Config.wallpaperInterval > 0 && root.state === "lockState"
        onTriggered: {
            root.pickRandomWallpaper();
        }
    }

    Component.onCompleted: {
        if (keyboard)
            capsLockOn = keyboard.capsLock;
        if (Config.randomWallpaper) {
            if (wallpaperFolderModel.status === FolderListModel.Ready && wallpaperFolderModel.count > 0) {
                pickRandomWallpaper();
            } else {
                activeWallpaperSource = resolveSource(Config.lockScreenBackground);
            }
        } else {
            activeWallpaperSource = resolveSource(Config.lockScreenBackground);
        }
    }
    onCapsLockOnChanged: {
        loginScreen.updateCapsLock();
    }

    states: [
        State {
            name: "lockState"
            PropertyChanges {
                target: lockScreen
                opacity: 1.0
            }
            PropertyChanges {
                target: loginScreen
                opacity: 0.0
            }
            PropertyChanges {
                target: loginScreen.loginContainer
                scale: 0.85
            }
            PropertyChanges {
                target: backgroundEffect
                blur: Config.lockScreenBlur > 0 ? (Config.lockScreenBlur / backgroundEffect.blurMax) : 0.0
                brightness: Config.lockScreenBrightness
                saturation: Config.lockScreenSaturation
            }
        },
        State {
            name: "loginState"
            PropertyChanges {
                target: lockScreen
                opacity: 0.0
            }
            PropertyChanges {
                target: loginScreen
                opacity: 1.0
            }
            PropertyChanges {
                target: loginScreen.loginContainer
                scale: 1.0
            }
            PropertyChanges {
                target: backgroundEffect
                blur: Config.loginScreenBlur > 0 ? (Config.loginScreenBlur / backgroundEffect.blurMax) : 1.0
                brightness: Config.loginScreenBrightness
                saturation: Config.loginScreenSaturation
            }
        }
    ]
    transitions: Transition {
        enabled: Config.enableAnimations
        PropertyAnimation {
            duration: 180
            properties: "opacity"
        }
        PropertyAnimation {
            duration: 400
            properties: "scale"
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            duration: 400
            properties: "blur"
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            duration: 400
            properties: "brightness"
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            duration: 400
            properties: "saturation"
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: mainFrame

        property variant geometry: screenModel.geometry(screenModel.primary)
        // x: geometry.x
        // y: geometry.y
        // width: geometry.width
        // height: geometry.height
        anchors.fill: parent

        // AnimatedImage { // `.gif`s are seg faulting with multi monitors... QT/SDDM issue?
        Image {
            // Background
            id: backgroundImage
            property string tsource: Config.randomWallpaper ? activeWallpaperSource : (root.state === "lockState" ? resolveSource(Config.lockScreenBackground) : resolveSource(Config.loginScreenBackground))

            property bool isVideo: {
                if (!tsource || tsource.toString().length === 0)
                    return false;
                var parts = tsource.toString().split(".");
                if (parts.length === 0)
                    return false;
                var ext = parts[parts.length - 1].toLowerCase();
                return ["avi", "mp4", "mov", "mkv", "m4v", "webm"].indexOf(ext) !== -1;
            }
            property bool displayColor: root.state === "lockState" && Config.lockScreenUseBackgroundColor || root.state === "loginState" && Config.loginScreenUseBackgroundColor
            property string placeholder: Config.animatedBackgroundPlaceholder

            anchors.fill: parent
            source: !isVideo ? tsource : ""
            cache: true
            mipmap: true
            fillMode: {
                if (Config.backgroundFillMode === "stretch") {
                    return Image.Stretch;
                } else if (Config.backgroundFillMode === "fit") {
                    return Image.PreserveAspectFit;
                } else {
                    return Image.PreserveAspectCrop;
                }
            }

            function updateVideo() {
                if (isVideo && tsource.toString().length > 0) {
                    backgroundVideo.source = tsource.indexOf("file://") === 0 ? tsource : Qt.resolvedUrl(tsource);

                    if (placeholder.length > 0)
                        source = resolveSource(placeholder);
                }
            }

            onSourceChanged: {
                updateVideo();
            }
            Component.onCompleted: {
                updateVideo();
            }
            onStatusChanged: {
                if (status === Image.Error) {
                    if (source !== "backgrounds/default.jpg" && source !== "") {
                        source = "backgrounds/default.jpg";
                    } else if (source === "backgrounds/default.jpg") {
                        // If even default fails, show color background
                        displayColor = true;
                    }
                }
            }

            Rectangle {
                id: backgroundColor
                anchors.fill: parent
                anchors.margins: 0
                color: root.state === "lockState" && Config.lockScreenUseBackgroundColor ? Config.lockScreenBackgroundColor : root.state === "loginState" && Config.loginScreenUseBackgroundColor ? Config.loginScreenBackgroundColor : "black"
                visible: parent.displayColor || (backgroundVideo.visible && parent.placeholder.length === 0)
            }

            // Video background support
            Video {
                id: backgroundVideo
                anchors.fill: parent
                visible: parent.isVideo && !parent.displayColor
                enabled: visible
                autoPlay: false
                loops: MediaPlayer.Infinite
                muted: true
                fillMode: {
                    if (Config.backgroundFillMode === "stretch") {
                        return VideoOutput.Stretch;
                    } else if (Config.backgroundFillMode === "fit") {
                        return VideoOutput.PreserveAspectFit;
                    } else {
                        return VideoOutput.PreserveAspectCrop;
                    }
                }

                onSourceChanged: {
                    if (source && source.toString().length > 0) {
                        backgroundVideo.play();
                    }
                }
                onErrorOccurred: function (error) {
                    if (error !== MediaPlayer.NoError && (!backgroundImage.placeholder || backgroundImage.placeholder.length === 0)) {
                        backgroundImage.displayColor = true;
                    }
                }
            }

            Component.onDestruction: {
                if (backgroundVideo) {
                    backgroundVideo.stop();
                    backgroundVideo.source = "";
                }
            }
        }
        MultiEffect {
            // Background effects
            id: backgroundEffect
            source: backgroundImage
            anchors.fill: parent
            blurMax: Math.max(Config.lockScreenBlur, Config.loginScreenBlur, 32)
            blurEnabled: backgroundImage.visible && (Config.lockScreenBlur > 0 || Config.loginScreenBlur > 0)
            blur: Config.lockScreenBlur > 0 ? (Config.lockScreenBlur / blurMax) : 0.0
            autoPaddingEnabled: false
        }

        Item {
            id: screenContainer
            anchors.fill: parent
            anchors.top: parent.top

            LockScreen {
                id: lockScreen
                z: root.state === "lockState" ? 2 : 1 // Fix tooltips from the login screen showing up on top of the lock screen.
                anchors.fill: parent
                focus: root.state === "lockState"
                enabled: root.state === "lockState"
                onLoginRequested: (key_text, shift) => {
                    if (Config.lockScreenIgnoreShift && shift)
                        return;

                    if (Config.lockScreenInputKeystroke && key_text && key_text.length === 1) {
                        // Ignore enter, backspace, tab, delete and other escape sequences:
                        if (!["\b", "\n", "\r", "\t"].some(es => key_text.includes(es)) && key_text.charCodeAt(0) !== 127)
                            loginScreen.password.text = key_text;
                    }
                    root.state = "loginState";
                    loginScreen.resetFocus();
                }
            }
            LoginScreen {
                id: loginScreen
                z: root.state === "loginState" ? 2 : 1
                anchors.fill: parent
                enabled: root.state === "loginState"
                opacity: 0.0
                onClose: {
                    root.state = "lockState";
                }
            }
        }
    }
}
