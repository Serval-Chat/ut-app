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
                
                // New DM button
                Components.IconButton {
                    id: addButton
                    iconName: "add"
                    onClicked: createDMClicked()
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
                    
                    delegate: ListItem {
                        id: dmItem
                        width: parent.width
                        height: units.gu(6)
                        color: selected ? Qt.darker(dmList.color, 1.15) : 
                               (dmMouseArea.containsMouse ? Qt.darker(dmList.color, 1.08) : "transparent")
                        
                        property bool selected: selectedConversationId === (modelData.recipientId || modelData._id || modelData.id)
                        property int unread: unreadCounts[modelData.recipientId || modelData._id || modelData.id] || 0
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: units.gu(1.5)
                            anchors.rightMargin: units.gu(1.5)
                            spacing: units.gu(1)
                            
                            Components.Avatar {
                                width: units.gu(4)
                                height: units.gu(4)
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.recipientName || modelData.username || ""
                                source: modelData.recipientAvatar || modelData.profilePicture || ""
                                showStatus: true
                                status: modelData.recipientStatus || "offline"
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - units.gu(7) - (unread > 0 ? units.gu(3) : 0)
                                spacing: units.gu(0.2)
                                
                                Label {
                                    text: modelData.recipientName || modelData.username || ""
                                    fontSize: "small"
                                    font.bold: unread > 0
                                    elide: Text.ElideRight
                                    width: parent.width
                                    color: selected || unread > 0 ? 
                                           Theme.palette.normal.foreground : 
                                           Theme.palette.normal.backgroundSecondaryText
                                }
                                
                                Label {
                                    text: modelData.lastMessage || ""
                                    fontSize: "x-small"
                                    elide: Text.ElideRight
                                    width: parent.width
                                    color: Theme.palette.normal.backgroundSecondaryText
                                    visible: modelData.lastMessage !== undefined
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
                            id: dmMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var recipientId = modelData.recipientId || modelData._id || modelData.id
                                var recipientName = modelData.recipientName || modelData.username || ""
                                var recipientAvatar = modelData.recipientAvatar || modelData.profilePicture || ""
                                conversationSelected(recipientId, recipientName, recipientAvatar)
                            }
                        }
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
        }
    }
}
