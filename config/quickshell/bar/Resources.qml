import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../lib"

Item {
    id: root
    implicitHeight: Theme.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        Resource {
            Layout.alignment: Qt.AlignVCenter
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            Layout.alignment: Qt.AlignVCenter
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: Config.options.bar.resources.alwaysShowSwap
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            Layout.alignment: Qt.AlignVCenter
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || !MprisController.hasPlayer
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }
    }
}
