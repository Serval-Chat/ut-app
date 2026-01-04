import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * ChannelListView - Channel list with categories for a server
 */
Rectangle {
    id: channelList
    
    property string serverId: ""
    property string serverName: ""
    property string serverIcon: ""
    property string selectedChannelId: ""
    property var channels: []
    property var categories: []
    property var unreadCounts: ({})  // channelId -> count
    property var mentionChannels: ({})  // channelId -> hasMention
    property var mutedChannels: ({})  // channelId -> muted
    property bool canManageChannels: false
    property bool showBackButton: false  // Whether to show back button for navigation
    
    // Track expanded state per category
    property var expandedCategories: ({})
    
    signal channelSelected(string channelId, string channelName, string channelType)
    signal serverSettingsClicked()
    signal createChannelClicked(string categoryId)
    signal categorySettingsClicked(string categoryId)
    signal channelSettingsClicked(string channelId)
    signal backClicked()
    
    color: Qt.darker(Theme.palette.normal.background, 1.08)
    width: units.gu(26)
    
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
                
                // Back button (for navigation when server list is hidden)
                AbstractButton {
                    id: backButton
                    width: units.gu(4)
                    height: parent.height
                    visible: showBackButton
                    z: 10  // Ensure it's above the header mouse area
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.foreground
                    }
                    
                    onClicked: backClicked()
                }
                
                Label {
                    text: serverName
                    font.bold: true
                    fontSize: "medium"
                    elide: Text.ElideRight
                    width: parent.width - (backButton.visible ? backButton.width : 0) - dropdownIcon.width - units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Icon {
                    id: dropdownIcon
                    width: units.gu(2)
                    height: units.gu(2)
                    name: "go-down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.palette.normal.backgroundSecondaryText
                }
            }
            
            MouseArea {
                id: serverHeaderMouse
                anchors.fill: parent
                anchors.leftMargin: backButton.visible ? backButton.width + units.gu(1.5) : 0  // Don't overlap back button
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
        
        // Channels list
        Flickable {
            id: channelFlickable
            width: parent.width
            height: parent.height - serverHeader.height - userPanel.height
            contentHeight: channelColumn.height + units.gu(2)
            clip: true
            
            Column {
                id: channelColumn
                width: parent.width
                topPadding: units.gu(1)
                spacing: units.gu(0.2)
                
                Repeater {
                    id: channelRepeater
                    model: buildChannelModel()
                    
                    Loader {
                        width: parent.width
                        sourceComponent: modelData.isCategory ? categoryComponent : channelComponent
                        
                        property var itemData: modelData
                    }
                }
            }
        }
        
        // User panel at bottom
        Rectangle {
            id: userPanel
            width: parent.width
            height: units.gu(6.5)
            color: Qt.darker(channelList.color, 1.1)
            
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
                    status: "online"
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
                        text: currentUserStatus || i18n.tr("Online")
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
                
                // Action buttons
                Row {
                    id: userActions
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(0.5)
                    
                    AbstractButton {
                        width: units.gu(3.5)
                        height: units.gu(3.5)
                        
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2)
                            height: units.gu(2)
                            name: "settings"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        onClicked: {
                            // Open user settings
                            pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"))
                        }
                    }
                }
            }
        }
    }
    
    // Current user info (to be set from parent)
    property string currentUserName: ""
    property string currentUserAvatar: ""
    property string currentUserStatus: ""
    
    // Component for category headers
    Component {
        id: categoryComponent
        
        Components.CategoryHeader {
            categoryId: itemData.id || ""
            categoryName: itemData.name || ""
            expanded: expandedCategories[itemData.id] !== false  // Default to expanded
            canManage: canManageChannels
            
            onToggleExpanded: {
                var newState = !expanded
                var newExpanded = Object.assign({}, expandedCategories)
                newExpanded[categoryId] = newState
                expandedCategories = newExpanded
            }
            
            onAddChannelClicked: createChannelClicked(categoryId)
            onSettingsClicked: categorySettingsClicked(categoryId)
        }
    }
    
    // Component for channel items
    Component {
        id: channelComponent
        
        Components.ChannelItem {
            visible: !itemData.categoryId || expandedCategories[itemData.categoryId] !== false
            height: visible ? units.gu(4) : 0
            channelId: itemData.id || itemData._id || ""
            channelName: itemData.name || ""
            channelType: itemData.type || "text"
            channelIcon: itemData.icon || ""
            description: itemData.description || ""
            selected: selectedChannelId === channelId
            unreadCount: unreadCounts[channelId] || 0
            hasMention: mentionChannels[channelId] || false
            muted: mutedChannels[channelId] || false
            
            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            onClicked: {
                selectedChannelId = channelId
                channelSelected(channelId, channelName, channelType)
            }
            
            onLongPressed: channelSettingsClicked(channelId)
        }
    }
    
    // Build a flat model with categories and their channels
    function buildChannelModel() {
        var model = []
        
        // Group channels by category
        var categoryMap = {}
        var uncategorized = []
        
        // Initialize category map
        for (var i = 0; i < categories.length; i++) {
            var cat = categories[i]
            var catId = cat._id || cat.id
            categoryMap[catId] = {
                category: cat,
                channels: []
            }
        }
        
        // Assign channels to categories
        for (var j = 0; j < channels.length; j++) {
            var ch = channels[j]
            if (ch.categoryId && categoryMap[ch.categoryId]) {
                categoryMap[ch.categoryId].channels.push(ch)
            } else {
                uncategorized.push(ch)
            }
        }
        
        // Add uncategorized channels first
        for (var k = 0; k < uncategorized.length; k++) {
            model.push({
                isCategory: false,
                id: uncategorized[k]._id || uncategorized[k].id,
                name: uncategorized[k].name,
                type: uncategorized[k].type,
                icon: uncategorized[k].icon,
                description: uncategorized[k].description,
                categoryId: null,
                position: uncategorized[k].position || 0
            })
        }
        
        // Sort categories by position
        var sortedCategories = categories.slice().sort(function(a, b) {
            return (a.position || 0) - (b.position || 0)
        })
        
        // Add categories and their channels
        for (var m = 0; m < sortedCategories.length; m++) {
            var category = sortedCategories[m]
            var catId2 = category._id || category.id
            
            // Add category header
            model.push({
                isCategory: true,
                id: catId2,
                name: category.name,
                position: category.position || 0
            })
            
            // Sort and add channels in this category
            var catChannels = categoryMap[catId2].channels.sort(function(a, b) {
                return (a.position || 0) - (b.position || 0)
            })
            
            for (var n = 0; n < catChannels.length; n++) {
                model.push({
                    isCategory: false,
                    id: catChannels[n]._id || catChannels[n].id,
                    name: catChannels[n].name,
                    type: catChannels[n].type,
                    icon: catChannels[n].icon,
                    description: catChannels[n].description,
                    categoryId: catId2,
                    position: catChannels[n].position || 0
                })
            }
        }
        
        return model
    }
    
    // Public function to refresh channels
    function refresh() {
        if (serverId) {
            SerchatAPI.getChannels(serverId, false)
        }
    }
}
