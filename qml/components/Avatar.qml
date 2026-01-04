import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * Avatar component - displays a user/server avatar with fallback initials
 */
Item {
    id: avatar
    
    property string source: ""
    property string name: ""
    property string status: "" // online, idle, dnd, offline
    property bool showStatus: false
    property color backgroundColor: LomiriColors.warmGrey
    property int fontSize: Math.floor(width * 0.4)
    
    width: units.gu(5)
    height: units.gu(5)
    
    Rectangle {
        id: background
        anchors.fill: parent
        radius: width / 2
        color: avatar.backgroundColor
        
        // Fallback initials
        Label {
            id: initialsLabel
            anchors.centerIn: parent
            text: getInitials(avatar.name)
            fontSize: "large"
            font.pixelSize: avatar.fontSize
            color: "white"
            visible: !avatarImage.visible
        }
        
        // Actual image
        Image {
            id: avatarImage
            anchors.fill: parent
            source: avatar.source
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant src: avatarImage
                fragmentShader: '
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
                    }'
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
        anchors.rightMargin: units.gu(0.2)
        anchors.bottomMargin: units.gu(0.2)
        visible: avatar.showStatus && avatar.status !== ""
        color: getStatusColor(avatar.status)
        border.width: units.dp(2)
        border.color: Theme.palette.normal.background
    }
    
    function getInitials(name) {
        if (!name) return "?"
        var parts = name.trim().split(" ")
        if (parts.length >= 2) {
            return (parts[0][0] + parts[1][0]).toUpperCase()
        }
        return name.substring(0, 2).toUpperCase()
    }
    
    function getStatusColor(status) {
        switch(status) {
            case "online": return "#43b581"
            case "idle": return "#faa61a"
            case "dnd": return "#f04747"
            default: return "#747f8d"
        }
    }
}
