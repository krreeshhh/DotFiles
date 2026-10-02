import QtQuick
import "../.."
import "LedgeModel.js" as Model

Rectangle {
    id: chip

    property var theme: null
    property string fontFamily: theme ? theme.fontFamily : Theme.fontFamily
    property string path: ""
    property string fileName: ""
    property string icon: ""
    property string ext: ""
    property bool isImage: false
    property bool selected: false
    property bool pinned: false
    property int selectionCount: 0
    property var dragPaths: [chip.path]

    readonly property string uri: Model.urlFromPath(path)

    signal copyFileRequested()
    signal copyPathRequested()
    signal openRequested()
    signal pinRequested()
    signal removeRequested()
    signal selectToggleRequested()
    signal selectRangeRequested(bool additive)
    signal dragStarted()
    signal dragFinished()

    implicitHeight: 60
    radius: theme ? theme.radius : 10
    color: chip.selected ? (theme ? theme.accentSoft : Theme.primaryContainer) : (hover.hovered ? (theme ? theme.raisedHover : Theme.surfaceVariant) : (theme ? theme.raised : "transparent"))
    border.width: 1
    border.color: chip.selected ? (theme ? theme.accent : Theme.primary) : (hover.hovered ? (theme ? theme.border : Theme.popupBorder) : "transparent")

    Behavior on color {
        ColorAnimation { duration: 90 }
    }

    property url dragImage: ""

    function refreshDragImage() {
        thumbBox.grabToImage(function (result) {
            chip.dragImage = result.url
        }, Qt.size(48, 48))
    }

    property bool allowMove: false
    readonly property int dragActions: chip.allowMove ? (Qt.CopyAction | Qt.MoveAction)
                                                      : Qt.CopyAction

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: chip.dragActions
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({
        "text/uri-list": Model.uriList(chip.dragPaths),
        "text/plain": chip.dragPaths.join("\n")
    })
    Drag.imageSource: chip.dragImage !== "" ? chip.dragImage : (chip.isImage ? chip.uri : "")
    Drag.imageSourceSize: Qt.size(48, 48)

    Drag.onDragFinished: action => {
        console.log("omarchy-ledge: dragged out", chip.dragPaths.length,
                    "file(s), reported action=" + action)
    }

    function beginDrag() {
        chip.dragStarted()
        chip.Drag.active = true
        chip.Drag.startDrag(chip.dragActions)
        if (chip.Drag.active)
            chip.Drag.active = false
        chip.dragFinished()
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.OpenHandCursor
        onHoveredChanged: if (hovered) chip.refreshDragImage()
    }

    MouseArea {
        id: body
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        preventStealing: true

        property point pressPoint: Qt.point(0, 0)
        property bool dragging: false

        onPressed: mouse => {
            pressPoint = Qt.point(mouse.x, mouse.y)
            dragging = false
        }

        onPositionChanged: mouse => {
            if (!pressed || dragging)
                return
            const dx = mouse.x - pressPoint.x
            const dy = mouse.y - pressPoint.y
            if (Math.sqrt(dx * dx + dy * dy) < 10)
                return
            dragging = true
            chip.beginDrag()
        }

        onClicked: mouse => {
            if (dragging)
                return
            if (mouse.modifiers & Qt.ShiftModifier)
                chip.selectRangeRequested((mouse.modifiers & Qt.ControlModifier) !== 0)
            else if (mouse.modifiers & Qt.ControlModifier)
                chip.selectToggleRequested()
            else
                chip.copyFileRequested()
        }
    }

    Rectangle {
        id: thumbBox
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 8
        clip: true
        color: chip.isImage && thumb.status === Image.Ready ? "transparent" : (theme ? theme.raised : Theme.surfaceVariant)

        Image {
            id: thumb
            anchors.fill: parent
            visible: chip.isImage && status === Image.Ready
            source: chip.isImage ? chip.uri : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 88
            sourceSize.height: 88
        }

        Text {
            anchors.centerIn: parent
            visible: !thumb.visible
            text: chip.isImage && thumb.status === Image.Error ? "\u{F02EE}" : chip.icon
            font.family: chip.fontFamily
            font.pixelSize: 22
            color: theme ? theme.muted : Theme.colOnSurfaceVariant
        }

        Text {
            visible: chip.pinned
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            text: "\u{F0403}"   // nf-md-pin
            font.family: chip.fontFamily
            font.pixelSize: 11
            color: theme ? theme.accent : Theme.primary
            style: Text.Outline
            styleColor: theme ? theme.surface : Theme.popupSurface
        }
    }

    Column {
        anchors.left: thumbBox.right
        anchors.leftMargin: 12
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: chip.fileName
            elide: Text.ElideMiddle
            color: theme ? theme.text : Theme.colOnSurface
            font.family: chip.fontFamily
            font.pixelSize: 13
        }

        Text {
            width: parent.width
            text: {
                if (chip.selected) {
                    if (hover.hovered && chip.selectionCount > 1)
                        return "drag takes all " + chip.selectionCount
                    return "selected"
                }
                if (hover.hovered)
                    return "drag · click copies · ctrl-click selects"
                if (chip.pinned)
                    return chip.ext ? chip.ext.toUpperCase() + " · pinned" : "pinned"
                return chip.ext ? chip.ext.toUpperCase() : "FILE"
            }
            elide: Text.ElideRight
            color: theme ? theme.muted : Theme.colOnSurfaceVariant
            font.family: chip.fontFamily
            font.pixelSize: 11
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        opacity: hover.hovered ? 1 : 0
        enabled: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }

        LedgeIconButton {
            theme: chip.theme
            icon: "\u{F018F}"   // nf-md-content_copy
            tooltip: "Copy path"
            tooltipEdge: "left"
            onClicked: chip.copyPathRequested()
        }

        LedgeIconButton {
            theme: chip.theme
            icon: "\u{F03CC}"   // nf-md-open_in_new
            tooltip: "Open"
            tooltipEdge: "left"
            onClicked: chip.openRequested()
        }

        LedgeIconButton {
            theme: chip.theme
            icon: chip.pinned ? "\u{F0403}" : "\u{F0931}"  // nf-md-pin / nf-md-pin_outline
            tooltip: chip.pinned ? "Unpin" : "Pin - kept on clear"
            tooltipEdge: "left"
            active: chip.pinned
            onClicked: chip.pinRequested()
        }

        LedgeIconButton {
            theme: chip.theme
            icon: "\u{F01B4}"   // nf-md-delete
            tooltip: "Remove"
            tooltipEdge: "left"
            danger: true
            onClicked: chip.removeRequested()
        }
    }
}
