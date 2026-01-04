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
    property bool showBackButton: false
    
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
                
                // Back button (for mobile view)
                AbstractButton {
                    id: backButton
                    width: units.gu(4)
                    height: parent.height
                    visible: showBackButton
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.baseText
                    }
                    
                    onClicked: backClicked()
                }
                
                Label {
                    text: i18n.tr("Direct Messages")
                    font.bold: true
                    fontSize: "medium"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (backButton.visible ? backButton.width : 0) - addButton.width - units.gu(2)
                }
                
                // New DM button
                AbstractButton {
                    id: addButton
                    width: units.gu(4)
                    height: parent.height
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "add"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
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
        
        // Search bar (optional)
        Rectangle {
            width: parent.width - units.gu(2)
            height: units.gu(4)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: units.gu(0.5)
            color: Qt.darker(dmList.color, 1.1)
            
            Row {
                anchors.fill: parent
                anchors.margins: units.gu(1)
                spacing: units.gu(0.5)
                
                Icon {
                    width: units.gu(2)
                    height: units.gu(2)
                    name: "find"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    text: i18n.tr("Find or start a conversation")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: createDMClicked()
            }
        }
        
        Item { height: units.gu(1); width: 1 }  // Spacer
        
        // Section header
        Item {
            width: parent.width
            height: units.gu(3)
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1.5)
                anchors.verticalCenter: parent.verticalCenter
                text: i18n.tr("DIRECT MESSAGES")
                fontSize: "x-small"
                font.bold: true
                color: Theme.palette.normal.backgroundSecondaryText
            }
        }
        
        // DM conversations list
        Flickable {
            width: parent.width
            height: parent.height - header.height - units.gu(9)
            contentHeight: dmColumn.height
            clip: true
            
            Column {
                id: dmColumn
                width: parent.width
                spacing: units.gu(0.5)
                
                // Empty state
                Item {
                    width: parent.width
                    height: units.gu(15)
                    visible: conversations.length === 0
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(1)
                        
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: units.gu(6)
                            height: units.gu(6)
                            name: "message"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n.tr("No conversations yet")
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n.tr("Start a new conversation!")
                            fontSize: "x-small"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                    }
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
        Rectangle {
            id: userPanel
            width: parent.width
            height: units.gu(6.5)
            color: Qt.darker(dmList.color, 1.1)
            
            Row {
                anchors.fill: parent
                anchors.margins: units.gu(1)
                spacing: units.gu(1)
                
                // User avatar
                Components.Avatar {
                    id: userAvatar
                    width: units.gu(4)
                    height: units.gu(4)
                    anchors.verticalCenter: parent.verticalCenter
                    name: currentUserName
                    source: currentUserAvatar
                    showStatus: true
                    status: currentUserStatus
                }
                
                // User info
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - userAvatar.width - userActions.width - units.gu(2)
                    spacing: units.gu(0.2)
                    
                    Label {
                        text: currentUserName
                        fontSize: "small"
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    Label {
                        text: currentUserStatus === "online" ? i18n.tr("Online") :
                              currentUserStatus === "idle" ? i18n.tr("Idle") :
                              currentUserStatus === "dnd" ? i18n.tr("Do Not Disturb") :
                              i18n.tr("Offline")
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
                
                // User actions
                Row {
                    id: userActions
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.5)
                    
                    AbstractButton {
                        width: units.gu(4)
                        height: units.gu(4)
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2)
                            height: units.gu(2)
                            name: "settings"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                    }
                }
            }
        }
    }
}
