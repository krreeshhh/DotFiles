import QtQuick

pragma Singleton

QtObject {
    id: border

    function surfaceSpec(section, token, fallbackColor, fallbackWidth) {
        return {
            color: fallbackColor,
            width: fallbackWidth || 1,
            top: fallbackWidth || 1,
            bottom: fallbackWidth || 1,
            left: fallbackWidth || 1,
            right: fallbackWidth || 1
        };
    }

    function flat(color, width) {
        return {
            color: color,
            width: width || 1,
            top: width || 1,
            bottom: width || 1,
            left: width || 1,
            right: width || 1
        };
    }

    function top(spec) { return spec && spec.top ? spec.top : 1; }
    function bottom(spec) { return spec && spec.bottom ? spec.bottom : 1; }
    function left(spec) { return spec && spec.left ? spec.left : 1; }
    function right(spec) { return spec && spec.right ? spec.right : 1; }
}
