import QtQuick 2.7
import Lomiri.Components 1.3
import QtGraphicalEffects 1.0

import SerchatAPI 1.0

/*
 * ServerIcon - A clickable server icon with selection indicator
 */
Item {
    id: serverIcon
    
    property string serverId: ""
    property string serverName: ""
    property string iconUrl: ""
    property bool selected: false
    property int unreadCount: 0
    property bool hasMention: false
    
    signal clicked()
    
    width: units.gu(6)
    height: units.gu(6)
    
    // Selection indicator pill
    Rectangle {
        id: selectionPill
        width: units.gu(0.5)
        height: selected ? units.gu(4) : (mouseArea.containsMouse ? units.gu(2.5) : units.gu(1))
        radius: width / 2
        color: Theme.palette.normal.foreground
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: selected || mouseArea.containsMouse || unreadCount > 0 || hasMention
        
        Behavior on height {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
    }
    
    Rectangle {
        id: iconBackground
        anchors.centerIn: parent
        width: units.gu(5)
        height: units.gu(5)
        radius: selected || mouseArea.containsMouse ? units.gu(1.5) : width / 2
        color: iconUrl && serverImage.status === Image.Ready ? "transparent" : SerchatAPI.markdownParser.colorFromString(serverName)
        
        Behavior on radius {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        
        // Server initials fallback (using C++ for consistency)
        Label {
            anchors.centerIn: parent
            text: SerchatAPI.markdownParser.getInitials(serverName)
            fontSize: "large"
            color: "white"
            visible: !iconUrl || serverImage.status !== Image.Ready
        }
        
        // Server icon image with rounded corners
        Image {
            id: serverImage
            anchors.fill: parent
            source: iconUrl
            fillMode: Image.PreserveAspectCrop
            visible: false  // Hidden - we show masked version
        }
        
        // Mask for rounded corners
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: iconBackground.radius
            visible: false
        }
        
        // Apply rounded mask to image
        OpacityMask {
            anchors.fill: parent
            source: serverImage
            maskSource: mask
            visible: serverImage.status === Image.Ready
        }
    }
    
    // Unread indicator / mention badge
    Rectangle {
        id: badge
        width: hasMention ? Math.max(units.gu(2.5), badgeLabel.width + units.gu(1)) : units.gu(1.2)
        height: hasMention ? units.gu(2.5) : units.gu(1.2)
        radius: height / 2
        color: hasMention ? "#f04747" : "white"
        anchors.right: iconBackground.right
        anchors.bottom: iconBackground.bottom
        anchors.rightMargin: -units.gu(0.3)
        anchors.bottomMargin: -units.gu(0.3)
        visible: unreadCount > 0 || hasMention
        
        Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: unreadCount > 99 ? "99+" : unreadCount.toString()
            fontSize: "x-small"
            color: "white"
            visible: hasMention
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: serverIcon.clicked()
    }
    
}
