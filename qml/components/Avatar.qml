import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * Avatar component - displays a user/server avatar with fallback initials
 * Handles both absolute URLs and relative API paths automatically.
 * Uses Qt's built-in image caching for performance.
 */
Item {
    id: avatar

    property string source: ""
    property string name: ""
    property string status: "" // online, idle, dnd, offline
    property bool showStatus: false
    property color backgroundColor: LomiriColors.warmGrey
    property int fontSize: Math.floor(width * 0.4)

    // Computed property to resolve the full image URL
    // Handles relative paths by prepending API base URL
    readonly property string resolvedSource: {
        if (!source || source === "") return ""
        // Already a full URL (http/https)
        if (source.indexOf("http://") === 0 || source.indexOf("https://") === 0) {
            return source
        }
        // Relative path starting with / - prepend API base URL
        if (source.indexOf("/") === 0) {
            // Remove trailing slash from base URL to avoid double slashes
            var baseUrl = SerchatAPI.apiBaseUrl
            if (baseUrl.charAt(baseUrl.length - 1) === "/") {
                baseUrl = baseUrl.substring(0, baseUrl.length - 1)
            }
            return baseUrl + source
        }
        // Other cases - return as-is
        return source
    }

    width: units.gu(5)
    height: units.gu(5)

    Rectangle {
        id: background
        anchors.fill: parent
        radius: width / 2
        color: avatar.backgroundColor

        // Fallback initials (using C++ for consistency)
        Label {
            id: initialsLabel
            anchors.centerIn: parent
            text: SerchatAPI.markdownParser.getInitials(avatar.name)
            fontSize: "large"
            font.pixelSize: avatar.fontSize
            color: "white"
            visible: !avatarImage.visible
        }

        // Actual image with caching enabled
        Image {
            id: avatarImage
            anchors.fill: parent
            source: avatar.resolvedSource
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            asynchronous: true  // Load asynchronously to prevent UI blocking
            cache: true         // Enable Qt's built-in image caching
            sourceSize.width: avatar.width * 2   // Cache at 2x for high-DPI displays
            sourceSize.height: avatar.height * 2
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant src: avatarImage
                fragmentShader: "
                    varying highp vec2 qt_TexCoord0;
                    uniform sampler2D src;
                    void main() {
                        highp vec2 center = vec2(0.5, 0.5);
                        highp float dist = distance(qt_TexCoord0, center);
                        if (dist > 0.5) {
                            gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
                        } else {
                            gl_FragColor = texture2D(src, qt_TexCoord0);
                        }
                    }"
            }
        }
    }
    
    // Status indicator
    Rectangle {
        id: statusIndicator
        width: units.gu(1.5)
        height: units.gu(1.5)
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -units.gu(0.1)
        anchors.bottomMargin: -units.gu(0.1)
        visible: avatar.showStatus && avatar.status !== ""
        color: Components.ColorUtils.statusColor(avatar.status)
        // border.width: units.gu(0.2)
        border.color: Theme.palette.normal.background
    }

}
