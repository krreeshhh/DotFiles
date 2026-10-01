import QtQuick
import "../Commons"

Rectangle {
    id: root
    property bool hasCursor: false
    property color foreground: Color.foreground
    property color accent: Color.accent

    color: hasCursor ? Qt.rgba(accent.r, accent.g, accent.b, 0.10) : "transparent"
    radius: Style.cornerRadius
}
