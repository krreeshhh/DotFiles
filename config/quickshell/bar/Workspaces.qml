import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

Item {
    id: root
    implicitWidth: wsRow.implicitWidth
    implicitHeight: 24
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    property var workspaceList: {
        var list = [];
        var maxWs = 5;
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            var values = Hyprland.workspaces.values;
            for (var i = 0; i < values.length; i++) {
                if (values[i].id > 0 && values[i].id <= 20) {
                    if (values[i].id > maxWs) maxWs = values[i].id;
                }
            }
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > maxWs) {
            maxWs = Hyprland.focusedWorkspace.id;
        }
        for (var j = 1; j <= maxWs; j++) {
            list.push(j);
        }
        return list;
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.workspaceList

            delegate: Item {
                id: dotItem
                property int wsId: modelData
                property bool isFocused: (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1) === wsId

                width: isFocused ? 24 : 7
                height: 7
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 3.5
                    color: dotItem.isFocused ? Theme.primary : (mouseArea.containsMouse ? "#b3ffffff" : "#59ffffff")

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + dotItem.wsId + " })"]);
                        Hyprland.dispatch("workspace " + dotItem.wsId);
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"e-1\" })"]);
            } else if (wheel.angleDelta.y < 0) {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"e+1\" })"]);
            }
        }
    }
}
