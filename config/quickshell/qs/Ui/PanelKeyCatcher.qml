import QtQuick

Item {
    id: keyCatcher
    focus: true

    signal moveRequested(int dx, int dy)
    signal activateRequested()
    signal closeRequested()
    signal tabRequested(int direction)
    signal textKey(string text)

    Keys.onEscapePressed: keyCatcher.closeRequested()
    Keys.onReturnPressed: keyCatcher.activateRequested()
    Keys.onEnterPressed: keyCatcher.activateRequested()
    Keys.onUpPressed: keyCatcher.moveRequested(0, -1)
    Keys.onDownPressed: keyCatcher.moveRequested(0, 1)
    Keys.onLeftPressed: keyCatcher.moveRequested(-1, 0)
    Keys.onRightPressed: keyCatcher.moveRequested(1, 0)
    Keys.onTabPressed: keyCatcher.tabRequested(1)
    Keys.onBacktabPressed: keyCatcher.tabRequested(-1)

    Keys.onPressed: event => {
        if (event.text && event.text.length > 0) {
            keyCatcher.textKey(event.text);
        }
    }
}
