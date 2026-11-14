import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Item {
    id: root

    property date displayDate: new Date()
    readonly property var today: new Date()

    readonly property var cells: {
        const d = root.displayDate;
        const year = d.getFullYear();
        const month = d.getMonth();
        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        let arr = [];
        for (let i = 0; i < firstDay; i++) arr.push({ day: 0 });
        for (let day = 1; day <= daysInMonth; day++) {
            const isToday = day === root.today.getDate()
                && month === root.today.getMonth()
                && year === root.today.getFullYear();
            arr.push({ day: day, isToday: isToday });
        }
        return arr;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer2Hover
                colRipple: Theme.colLayer1Active
                onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() - 1, 1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    iconSize: 20
                    color: Theme.colOnLayer1
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDateTime(root.displayDate, "MMMM yyyy")
                font.pixelSize: Theme.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Theme.colOnLayer0
            }

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Theme.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Theme.colLayer2Hover
                colRipple: Theme.colLayer1Active
                onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() + 1, 1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    iconSize: 20
                    color: Theme.colOnLayer1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                delegate: StyledText {
                    required property var modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Theme.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: Theme.colSubtext
                }
            }
        }

        Grid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            spacing: 0

            Repeater {
                model: root.cells
                delegate: Item {
                    required property var modelData
                    width: grid.width / 7
                    height: 34

                    Rectangle {
                        visible: modelData.day > 0
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: height / 2
                        color: modelData.isToday ? Theme.primary : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.day > 0 ? modelData.day : ""
                            font.pixelSize: Theme.font.pixelSize.smaller
                            color: modelData.isToday ? Theme.onPrimary : Theme.colOnLayer1
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDateTime(root.today, "dddd, dd MMMM")
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.colOnLayer1
            }
            StyledText {
                text: "Today"
                font.pixelSize: Theme.font.pixelSize.smaller
                color: Theme.primary
            }
        }
    }
}
