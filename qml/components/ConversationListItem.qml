import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * ConversationListItem - Reusable conversation/DM list item
 * 
 * Displays a conversation with avatar, name, last message preview, and unread badge.
 * Used in DMListView and can be reused for group DMs in the future.
 */
ListItem {
    id: conversationItem
    
    property var conversation: ({})
    property string selectedId: ""
    property var unreadCounts: ({})
    property color panelColor: Theme.palette.normal.background
    
    signal clicked(string recipientId, string recipientName, string recipientAvatar)
    
    width: parent ? parent.width : units.gu(26)
    height: units.gu(6)
    
    // Computed properties
    readonly property string recipientId: conversation.recipientId || conversation._id || conversation.id || ""
    readonly property string recipientName: conversation.recipientName || conversation.username || ""
    readonly property string recipientAvatar: conversation.recipientAvatar || 
                                               (conversation.profilePicture ? SerchatAPI.apiBaseUrl + conversation.profilePicture : "")
    readonly property string recipientStatus: conversation.recipientStatus || "offline"
    readonly property string lastMessage: conversation.lastMessage || ""
    readonly property bool selected: selectedId === recipientId
    readonly property int unread: unreadCounts[recipientId] || 0
    
    color: selected ? Qt.darker(panelColor, 1.15) : 
           (mouseArea.containsMouse ? Qt.darker(panelColor, 1.08) : "transparent")
    
    Row {
        anchors.fill: parent
        anchors.leftMargin: units.gu(1.5)
        anchors.rightMargin: units.gu(1.5)
        spacing: units.gu(1)
        
        Components.Avatar {
            width: units.gu(4)
            height: units.gu(4)
            anchors.verticalCenter: parent.verticalCenter
            name: conversationItem.recipientName
            source: conversationItem.recipientAvatar
            showStatus: true
            status: conversationItem.recipientStatus
        }
        
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - units.gu(7) - (unread > 0 ? units.gu(3) : 0)
            spacing: units.gu(0.2)
            
            Label {
                text: conversationItem.recipientName
                fontSize: "small"
                font.bold: unread > 0
                elide: Text.ElideRight
                width: parent.width
                color: selected || unread > 0 ? 
                       Theme.palette.normal.foreground : 
                       Theme.palette.normal.backgroundSecondaryText
            }
            
            Label {
                text: conversationItem.lastMessage
                fontSize: "x-small"
                elide: Text.ElideRight
                width: parent.width
                color: Theme.palette.normal.backgroundSecondaryText
                visible: conversationItem.lastMessage !== ""
            }
        }
        
        // Unread badge
        Rectangle {
            width: units.gu(2.5)
            height: units.gu(2.5)
            radius: width / 2
            color: LomiriColors.red
            anchors.verticalCenter: parent.verticalCenter
            visible: unread > 0
            
            Label {
                anchors.centerIn: parent
                text: unread > 99 ? "99+" : unread.toString()
                fontSize: "x-small"
                color: "white"
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: conversationItem.clicked(recipientId, recipientName, recipientAvatar)
    }
}
