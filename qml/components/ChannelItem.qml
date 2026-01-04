import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * ChannelItem - A channel list item with icon and name
 */
Item {
    id: channelItem
    
    property string channelId: ""
    property string channelName: ""
    property string channelType: "text"  // text or voice
    property string channelIcon: ""
    property string description: ""
    property bool selected: false
    property int unreadCount: 0
    property bool hasMention: false
    property bool muted: false
    
    signal clicked()
    signal longPressed()
    
    width: parent ? parent.width : units.gu(25)
    height: units.gu(4)
    
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)
        radius: units.gu(0.5)
        color: selected ? Theme.palette.selected.background : 
               (mouseArea.containsMouse ? Theme.palette.highlighted.background : "transparent")
        
        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        spacing: units.gu(1)
        
        // Channel icon
        Icon {
            id: channelTypeIcon
            width: units.gu(2.2)
            height: units.gu(2.2)
            anchors.verticalCenter: parent.verticalCenter
            name: getChannelIcon()
            color: selected || unreadCount > 0 ? Theme.palette.normal.foreground : 
                   Theme.palette.normal.backgroundSecondaryText
        }
        
        // Channel name
        Label {
            id: channelNameLabel
            text: channelName
            fontSize: "small"
            anchors.verticalCenter: parent.verticalCenter
            color: selected || unreadCount > 0 ? Theme.palette.normal.foreground : 
                   Theme.palette.normal.backgroundSecondaryText
            font.bold: unreadCount > 0
            elide: Text.ElideRight
            width: parent.width - channelTypeIcon.width - badgeContainer.width - units.gu(3)
        }
        
        // Badge / muted indicator container
        Item {
            id: badgeContainer
            width: badge.visible ? badge.width : (mutedIcon.visible ? mutedIcon.width : 0)
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            
            // Unread badge
            Rectangle {
                id: badge
                width: Math.max(units.gu(2.5), badgeLabel.width + units.gu(1))
                height: units.gu(2.2)
                radius: height / 2
                color: hasMention ? "#f04747" : Theme.palette.normal.activity
                anchors.verticalCenter: parent.verticalCenter
                visible: unreadCount > 0 && !muted
                
                Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: unreadCount > 999 ? "999+" : unreadCount.toString()
                    fontSize: "x-small"
                    color: "white"
                }
            }
            
            // Muted icon
            Icon {
                id: mutedIcon
                width: units.gu(2)
                height: units.gu(2)
                name: "audio-volume-muted"
                anchors.verticalCenter: parent.verticalCenter
                visible: muted
                color: Theme.palette.normal.backgroundSecondaryText
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: channelItem.clicked()
        onPressAndHold: channelItem.longPressed()
    }
    
    function getChannelIcon() {
        // Map API icon names to Lomiri/Suru icons, or use type-based fallback
        if (channelIcon) {
            // Map common custom icons to available Lomiri icons
            switch(channelIcon) {
                case "code_brackets": return "stock_document"
                case "megaphone": return "broadcast"
                case "newspaper": return "note"
                case "book_with_checkmark": return "tick"
                case "info_mark": return "info"
                case "hashtag": return "edit"
                default: return "edit"  // Fallback for unknown icons
            }
        }
        switch(channelType) {
            case "voice": return "audio-speakers-symbolic"
            case "announcement": return "broadcast"
            case "forum": return "view-list-symbolic"
            default: return "edit"  // text channel
        }
    }
}
