import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#050810"

    // Responsive scaling factor calibrated for 1080p display
    readonly property real s: Math.max(height / 1080, 0.75)

    // Config options with safe fallbacks
    readonly property color accentColor: (typeof config !== "undefined" && config.accentColor) ? config.accentColor : "#6090b8"
    readonly property color accentHoverColor: (typeof config !== "undefined" && config.accentHoverColor) ? config.accentHoverColor : "#80b0d8"
    readonly property color errorColor: (typeof config !== "undefined" && config.errorColor) ? config.errorColor : "#d06060"
    readonly property string passwordGlyph: (typeof config !== "undefined" && config.passwordMask) ? config.passwordMask : "✦"

    // Wayland Cursor Fix
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
    }

    // Quickshell check
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined

    // State
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property real uiOpacity: 0

    TextConstants { id: textConstants }

    FolderListModel {
        id: fontFolder
        folder: Qt.resolvedUrl("font")
        nameFilters: ["*.ttf", "*.otf"]
    }

    FontLoader {
        id: customFont
        source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : ""
    }

    readonly property string fontName: (customFont.name && customFont.name.length > 0) ? customFont.name : "sans-serif"

    // Helper functions for safe model data resolution
    function getSessionName() {
        if (sessionHelper.currentItem && sessionHelper.currentItem.sName) {
            return sessionHelper.currentItem.sName;
        }
        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
            return sessionModel.data(sessionModel.index(root.sessionIndex, 0), Qt.DisplayRole) || "Session";
        }
        return "Hyprland";
    }

    function getUserDisplayName() {
        if (userHelper.currentItem && userHelper.currentItem.uName) {
            return userHelper.currentItem.uName;
        }
        if (typeof userModel !== "undefined" && userModel.lastUser) {
            return userModel.lastUser;
        }
        return "User";
    }

    function getUserLoginName() {
        if (userHelper.currentItem && userHelper.currentItem.uLogin) {
            return userHelper.currentItem.uLogin;
        }
        if (typeof userModel !== "undefined" && userModel.lastUser) {
            return userModel.lastUser;
        }
        return "";
    }

    // Model Helpers
    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        visible: false
        width: 0; height: 0
        delegate: Item { property string sName: (typeof model !== "undefined" && model.name) ? model.name : "" }
    }

    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        opacity: 0; width: 1; height: 1; z: -100
        delegate: Item {
            property string uName: (typeof model !== "undefined") ? (model.realName || model.name || "") : ""
            property string uLogin: (typeof model !== "undefined") ? (model.name || "") : ""
        }
    }

    // Entrance Animation
    Component.onCompleted: {
        fadeAnim.start();
        if (typeof keyboard !== "undefined") {
            keyboard.numLock = true;
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: passwordField.forceActiveFocus()
    }

    NumberAnimation {
        id: fadeAnim
        target: root
        property: "uiOpacity"
        from: 0
        to: 1
        duration: 1200
        easing.type: Easing.OutCubic
    }

    // Visual Backgrounds & Gradients
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#080c14" }
            GradientStop { position: 0.5; color: "#0e1420" }
            GradientStop { position: 1.0; color: "#050810" }
        }
    }

    Loader {
        anchors.fill: parent
        source: "BackgroundVideo.qml"
    }

    RadialGradient {
        anchors.fill: parent
        opacity: (typeof config !== "undefined" && config.dimOpacity) ? parseFloat(config.dimOpacity) : 0.75
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#cc000000" }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 240 * s
        opacity: 0.70
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#ee000000" }
        }
    }

    // Top-Left Clock & Date Header
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 80 * s
        anchors.topMargin: 70 * s
        spacing: 10 * s
        opacity: root.uiOpacity

        Text {
            id: clockText
            text: Qt.formatTime(new Date(), (typeof config !== "undefined" && config.clockFormat) ? config.clockFormat : "HH:mm")
            color: "white"
            font.family: root.fontName
            font.pixelSize: 100 * s
            font.weight: Font.Thin
            layer.enabled: true
            layer.effect: DropShadow { color: "#80000000"; radius: 12; samples: 16 }
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatTime(new Date(), (typeof config !== "undefined" && config.clockFormat) ? config.clockFormat : "HH:mm")
            }
        }

        Row {
            spacing: 12 * s
            Rectangle {
                width: 28 * s
                height: 2 * s
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Qt.formatDate(new Date(), (typeof config !== "undefined" && config.dateFormat) ? config.dateFormat : "dddd · MMMM d").toUpperCase()
                color: root.accentColor
                font.family: root.fontName
                font.pixelSize: 14 * s
                font.letterSpacing: 3 * s
            }
        }
    }

    // Bottom-Right Login Panel
    Column {
        id: loginPanel
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 60 * s
        anchors.bottomMargin: 120 * s
        width: 320 * s
        spacing: 0
        opacity: root.uiOpacity

        // User Switcher
        Text {
            id: userDisplay
            anchors.right: parent.right
            text: root.getUserDisplayName()
            color: "white"
            font.family: root.fontName
            font.pixelSize: 26 * s
            font.letterSpacing: 2 * s
            scale: uMa.containsMouse ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            transform: Translate { id: uTrans; x: 0 }

            MouseArea {
                id: uMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof userModel !== "undefined" && userModel.rowCount() > 1) {
                        uToggleAnim.start();
                    }
                }
            }

            SequentialAnimation {
                id: uToggleAnim
                ParallelAnimation {
                    NumberAnimation { target: userDisplay; property: "opacity"; to: 0; duration: 120 }
                    NumberAnimation { target: uTrans; property: "x"; to: 15 * s; duration: 120 }
                }
                ScriptAction {
                    script: {
                        if (typeof userModel !== "undefined" && userModel.rowCount() > 0) {
                            root.userIndex = (root.userIndex + 1) % userModel.rowCount();
                        }
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: userDisplay; property: "opacity"; to: 1; duration: 180 }
                    NumberAnimation { target: uTrans; property: "x"; to: 0; duration: 180 }
                }
            }
        }

        Item { width: 1; height: 24 * s }

        // Password Input Row
        Item {
            width: parent.width
            height: 40 * s

            TextInput {
                id: passwordField
                anchors.left: parent.left
                anchors.right: arrowHint.left
                anchors.rightMargin: 14 * s
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                font.family: root.fontName
                font.pixelSize: 16 * s
                echoMode: TextInput.NoEcho
                focus: true
                clip: true
                cursorVisible: false
                cursorDelegate: Item { width: 0; height: 0 }
                selectionColor: root.accentColor
                property bool wasClicked: false
                onTextEdited: errorMessage.text = ""
                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed: doLogin()

                // Star/Blade Mask Repeater
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * s

                    Repeater {
                        model: passwordField.text.length
                        delegate: Text {
                            text: root.passwordGlyph
                            color: "white"
                            font.family: root.fontName
                            font.pixelSize: 14 * s
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Pulsing Glow Cursor
                    Text {
                        id: customCursor
                        text: root.passwordGlyph
                        color: "white"
                        font.family: root.fontName
                        font.pixelSize: 14 * s
                        verticalAlignment: Text.AlignVCenter
                        visible: passwordField.focus && (passwordField.text.length > 0 || passwordField.wasClicked)
                        layer.enabled: true
                        layer.effect: DropShadow { color: root.accentHoverColor; radius: 10; samples: 16 }
                        SequentialAnimation {
                            loops: Animation.Infinite
                            running: customCursor.visible
                            NumberAnimation { target: customCursor; property: "opacity"; from: 1.0; to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { target: customCursor; property: "opacity"; from: 0.25; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // Placeholder
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enter password"
                    color: "white"
                    opacity: (passwordField.text.length === 0 && !passwordField.wasClicked) ? 0.35 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    font.family: root.fontName
                    font.pixelSize: 15 * s
                    font.letterSpacing: 2 * s
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        passwordField.forceActiveFocus();
                        passwordField.wasClicked = true;
                    }
                }
            }

            // Submit Arrow Button
            Text {
                id: arrowHint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                color: arrowMa.containsMouse ? root.accentHoverColor : root.accentColor
                font.pixelSize: 20 * s
                opacity: passwordField.text.length > 0 ? 1.0 : 0.4
                scale: arrowMa.containsMouse ? 1.15 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: arrowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }
        }

        // Input Underline
        Rectangle {
            width: parent.width
            height: 2 * s
            color: passwordField.activeFocus ? root.accentHoverColor : "#406090b8"
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        Item { width: 1; height: 12 * s }

        // Error Message Banner
        Text {
            id: errorMessage
            anchors.right: parent.right
            height: 18 * s
            verticalAlignment: Text.AlignTop
            font.family: root.fontName
            font.pixelSize: 12 * s
            font.letterSpacing: 1.5 * s
            color: root.errorColor
            text: ""
        }
    }

    // Bottom Decorative Separator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 60 * s
        anchors.rightMargin: 60 * s
        anchors.bottomMargin: 40 * s
        height: 1 * s
        color: "#20a0c8e0"
        opacity: root.uiOpacity
    }

    // Bottom Bar (Session Selector & Power Actions)
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 60 * s
        height: 40 * s
        opacity: root.uiOpacity * 0.9

        // Session Selector Switcher (Bottom Left)
        Item {
            width: sessionSwitchRow.implicitWidth
            height: sessionSwitchRow.implicitHeight
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.isQuickshell

            Row {
                id: sessionSwitchRow
                spacing: 10 * s
                opacity: sMa.containsMouse ? 1.0 : 0.80
                scale: sMa.containsMouse ? 1.05 : 1.0
                transform: Translate { id: sTrans; x: 0 }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    text: "◈"
                    color: root.accentColor
                    font.pixelSize: 12 * s
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: sessionLabel
                    text: root.getSessionName()
                    color: "white"
                    opacity: 0.8
                    font.family: root.fontName
                    font.pixelSize: 13 * s
                    font.letterSpacing: 1 * s
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: sMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof sessionModel !== "undefined" && sessionModel.rowCount() > 1) {
                        sToggleAnim.start();
                    }
                }
            }

            SequentialAnimation {
                id: sToggleAnim
                ParallelAnimation {
                    NumberAnimation { target: sessionLabel; property: "opacity"; to: 0; duration: 120 }
                    NumberAnimation { target: sTrans; property: "x"; to: 10 * s; duration: 120 }
                }
                ScriptAction {
                    script: {
                        if (typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0) {
                            root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount();
                        }
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: sessionLabel; property: "opacity"; to: 0.8; duration: 180 }
                    NumberAnimation { target: sTrans; property: "x"; to: 0; duration: 180 }
                }
            }
        }

        // Power Actions (Bottom Right)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 32 * s

            Text {
                text: "Restart"
                color: "white"
                opacity: rMa.containsMouse ? 1.0 : 0.5
                font.family: root.fontName
                font.pixelSize: 13 * s
                font.letterSpacing: 1.5 * s
                scale: rMa.containsMouse ? 1.08 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: rMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof sddm !== "undefined") {
                            sddm.reboot();
                        }
                    }
                }
            }

            Text {
                text: "Shut Down"
                color: "white"
                opacity: pMa.containsMouse ? 1.0 : 0.5
                font.family: root.fontName
                font.pixelSize: 13 * s
                font.letterSpacing: 1.5 * s
                scale: pMa.containsMouse ? 1.08 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: pMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof sddm !== "undefined") {
                            sddm.powerOff();
                        }
                    }
                }
            }
        }
    }

    // Login Action
    function doLogin() {
        var uname = root.getUserLoginName();
        if (typeof sddm !== "undefined") {
            sddm.login(uname, passwordField.text, root.sessionIndex);
        }
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            errorMessage.text = "ACCESS DENIED";
            passwordField.text = "";
            passwordField.focus = true;
            shakeAnim.start();
        }
    }

    // Login Failure Shake Animation
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: 75 * s; duration: 40 }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: 45 * s; duration: 40 }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: 70 * s; duration: 40 }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: 50 * s; duration: 40 }
        NumberAnimation { target: loginPanel; property: "anchors.rightMargin"; to: 60 * s; duration: 40 }
    }
}
