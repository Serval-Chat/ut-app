pragma Singleton
import QtQuick 2.7

import SerchatAPI 1.0

/*
 * ColorUtils - Shared color utility functions
 * Delegates to C++ for better performance.
 */
QtObject {
    // Generate a consistent color from a string (e.g., username)
    // Uses C++ implementation for better performance
    function colorFromString(str) {
        return SerchatAPI.markdownParser.colorFromString(str || "")
    }

    // Status indicator colours
    function statusColor(status) {
        switch(status) {
            case "online": return "#43b581"
            case "idle": return "#faa61a"
            case "dnd": return "#f04747"
            default: return "#747f8d"
        }
    }
}