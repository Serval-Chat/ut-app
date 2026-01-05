import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * ChannelListView - Channel list with categories for a server
 * 
 * Uses SerchatAPI.channelListModel which provides:
 * - Sorted categories by position
 * - Uncategorized channels at the top
 * - Expandable category headers
 * - Real-time updates when channels/categories change
 */
Rectangle {
    id: channelList
    
    property string serverId: ""
    property string serverName: ""
    property string serverIcon: ""
    property string selectedChannelId: ""
    property var unreadCounts: ({})  // channelId -> count
    property var mentionChannels: ({})  // channelId -> hasMention
    property var mutedChannels: ({})  // channelId -> muted
    property bool canManageChannels: false
    
    signal channelSelected(string channelId, string channelName, string channelType)
    signal serverSettingsClicked()
    signal createChannelClicked(string categoryId)
    signal categorySettingsClicked(string categoryId)
    signal channelSettingsClicked(string channelId)
    signal backClicked()
    
    color: Qt.darker(theme.palette.normal.background, 1.08)
    width: units.gu(26)
    
    // Current user info (to be set from parent)
    property string currentUserName: ""
    property string currentUserAvatar: ""
    property string currentUserStatus: ""
    
    Column {
        anchors.fill: parent
        
        // Server header
        Rectangle {
            id: serverHeader
            width: parent.width
            height: units.gu(6)
            color: serverHeaderMouse.pressed ? Qt.darker(channelList.color, 1.1) : 
                   (serverHeaderMouse.containsMouse ? Qt.darker(channelList.color, 1.05) : channelList.color)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)
                
                Label {
                    text: serverName
                    font.bold: true
                    fontSize: "medium"
                    elide: Text.ElideRight
                    width: parent.width - dropdownIcon.width - units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Icon {
                    id: dropdownIcon
                    width: units.gu(2)
                    height: units.gu(2)
                    name: "go-down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.palette.normal.backgroundSecondaryText
                }
            }
            
            MouseArea {
                id: serverHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: serverSettingsClicked()
            }
            
            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.dp(1)
                color: Qt.darker(channelList.color, 1.2)
            }
        }
        
        // Channels list using the C++ model
        ListView {
            id: channelListView
            width: parent.width
            height: parent.height - serverHeader.height - userPanel.height
            clip: true
            topMargin: units.gu(1)
            spacing: units.gu(0.2)
            
            model: SerchatAPI.channelListModel
            
            delegate: Loader {
                id: delegateLoader
                width: channelListView.width
                
                // Respect visibility from the model (handles category expansion)
                visible: model.visible
                height: visible ? (model.itemType === "category" ? units.gu(3.5) : units.gu(4)) : 0
                
                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                
                sourceComponent: model.itemType === "category" ? categoryDelegate : channelDelegate
                
                // Pass model data to components via properties
                property string itemId: model.itemId
                property string itemName: model.name
                property string itemCategoryId: model.categoryId || ""
                property string itemChannelType: model.channelType || "text"
                property string itemIcon: model.icon || ""
                property string itemDescription: model.description || ""
                property bool itemExpanded: model.expanded
            }
        }
        
        // User panel at bottom
        Components.UserPanel {
            id: userPanel
            width: parent.width
            userName: currentUserName
            userAvatar: currentUserAvatar
            userStatus: "online"
            
            onSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"))
            }
        }
    }
    
    // Category delegate component
    Component {
        id: categoryDelegate
        
        Components.CategoryHeader {
            categoryId: itemId
            categoryName: itemName
            expanded: itemExpanded
            canManage: canManageChannels
            
            onToggleExpanded: {
                SerchatAPI.channelListModel.toggleCategoryExpanded(categoryId)
            }
            
            onAddChannelClicked: createChannelClicked(categoryId)
            onSettingsClicked: categorySettingsClicked(categoryId)
        }
    }
    
    // Channel delegate component
    Component {
        id: channelDelegate
        
        Components.ChannelItem {
            channelId: itemId
            channelName: itemName
            channelType: itemChannelType
            channelIcon: itemIcon
            description: itemDescription
            selected: selectedChannelId === channelId
            // Use C++ unread tracking, fall back to legacy counts
            // Reference unreadStateVersion to trigger re-evaluation when state changes
            unreadCount: {
                var v = SerchatAPI.unreadStateVersion  // Trigger re-binding on change
                return SerchatAPI.hasUnreadMessages(channelList.serverId, channelId) ? 
                       Math.max(1, unreadCounts[channelId] || 0) : 
                       (unreadCounts[channelId] || 0)
            }
            hasMention: mentionChannels[channelId] || false
            muted: mutedChannels[channelId] || false
            
            onClicked: {
                selectedChannelId = channelId
                channelSelected(channelId, channelName, channelType)
            }
            
            onLongPressed: channelSettingsClicked(channelId)
        }
    }
    
    // Update the model when serverId changes
    onServerIdChanged: {
        if (serverId) {
            SerchatAPI.channelListModel.serverId = serverId
        }
    }
    
    // Public function to refresh channels
    function refresh() {
        if (serverId) {
            SerchatAPI.getChannels(serverId, false)
            SerchatAPI.getCategories(serverId, false)
        }
    }
}
