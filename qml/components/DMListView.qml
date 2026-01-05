import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * DMListView - Direct Messages list view (shown when Home is selected)
 */
Rectangle {
    id: dmList
    
    property var conversations: []  // List of DM conversations
    property var unreadCounts: ({})  // conversationId -> count
    property string selectedConversationId: ""
    property string currentUserName: ""
    property string currentUserAvatar: ""
    property string currentUserStatus: "online"
    
    signal conversationSelected(string recipientId, string recipientName, string recipientAvatar)
    signal createDMClicked()
    signal backClicked()
    
    color: Qt.darker(Theme.palette.normal.background, 1.08)
    width: units.gu(26)
    
    Column {
        anchors.fill: parent
        
        // Header
        Rectangle {
            id: header
            width: parent.width
            height: units.gu(6)
            color: dmList.color
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)
                
                Label {
                    text: i18n.tr("Direct Messages")
                    font.bold: true
                    fontSize: "medium"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - addButton.width - units.gu(2)
                }
            }
            
            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.dp(1)
                color: Qt.darker(dmList.color, 1.15)
            }
        }
        
        // Search bar
        Components.SearchBox {
            width: parent.width - units.gu(2)
            anchors.horizontalCenter: parent.horizontalCenter
            placeholderText: i18n.tr("Find or start a conversation")
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: createDMClicked()
            }
        }
        
        Item { height: units.gu(1); width: 1 }  // Spacer
        
        // Section header
        Components.SectionHeader {
            title: i18n.tr("DIRECT MESSAGES")
            fontSize: "x-small"
            titleColor: Theme.palette.normal.backgroundSecondaryText
        }
        
        // DM conversations list
        Flickable {
            width: parent.width
            height: parent.height - header.height - units.gu(16)
            contentHeight: dmColumn.height
            clip: true
            
            Column {
                id: dmColumn
                width: parent.width
                spacing: units.gu(0.5)
                
                // Empty state
                Components.EmptyState {
                    width: parent.width
                    visible: conversations.length === 0
                    iconName: "message"
                    title: i18n.tr("No conversations yet")
                    description: i18n.tr("Start a new conversation!")
                }
                
                // Conversation items
                Repeater {
                    model: conversations
                    
                    Components.ConversationListItem {
                        width: parent.width
                        conversation: modelData
                        selectedId: selectedConversationId
                        unreadCounts: dmList.unreadCounts
                        panelColor: dmList.color
                        
                        onClicked: conversationSelected(recipientId, recipientName, recipientAvatar)
                    }
                }
            }
        }
        
        // User panel at bottom
        Components.UserPanel {
            width: parent.width
            userName: currentUserName
            userAvatar: currentUserAvatar
            userStatus: currentUserStatus
            
            onSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"))
            }
            
            onProfileClicked: {
                pageStack.push(Qt.resolvedUrl("../ProfilePage.qml"), {
                    userId: "me"
                })
            }
        }
    }
}
