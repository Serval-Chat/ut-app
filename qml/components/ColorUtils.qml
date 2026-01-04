pragma Singleton
import QtQuick 2.7

/*
 * ColorUtils - Shared color utility functions
 * Instantiate this component to access utility functions.
 */
QtObject {
    // Generate a consistent color from a string (e.g., username)
    function colorFromString(str) {
        var name = str || "user"
        var colors = ["#7289da", "#43b581", "#faa61a", "#f04747", "#9b59b6"]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        return colors[Math.abs(hash) % colors.length]
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