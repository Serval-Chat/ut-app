import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * CreateDMDialog - Dialog for starting a new DM conversation
 * Allows searching for friends to start a conversation with
 */
Item {
    id: createDMDialog
    
    property var friends: []  // List of friends to choose from
    property bool loading: false
    property string searchQuery: ""
    property bool opened: false
    
    signal conversationStarted(string recipientId, string recipientName, string recipientAvatar)
    signal closed()
    
    anchors.fill: parent
    visible: opened
    z: 1000
    
    // Filtered friends based on search
    property var filteredFriends: {
        if (!searchQuery || searchQuery.trim() === "") {
            return friends
        }
        var query = searchQuery.toLowerCase()
        return friends.filter(function(friend) {
            var displayName = (friend.displayName || friend.username || "").toLowerCase()
            var username = (friend.username || "").toLowerCase()
            return displayName.indexOf(query) !== -1 || username.indexOf(query) !== -1
        })
    }
    
    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: opened ? 0.4 : 0
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: close()
        }
    }
    
    // Dialog container
    Rectangle {
        id: dialogBox
        width: Math.min(parent.width - units.gu(4), units.gu(50))
        height: Math.min(dialogContent.height + units.gu(4), parent.height - units.gu(8))
        anchors.centerIn: parent
        radius: units.gu(1.5)
        color: Theme.palette.normal.background
        
        // Scale animation
        scale: opened ? 1 : 0.8
        opacity: opened ? 1 : 0
        
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        
        Column {
            id: dialogContent
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: units.gu(2)
            spacing: units.gu(1.5)
            
            // Header
            Item {
                width: parent.width
                height: units.gu(4)
                
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(2)
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("New Message")
                    fontSize: "large"
                    font.bold: true
                }
                
                AbstractButton {
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(1)
                    width: units.gu(4)
                    height: parent.height
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "close"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    onClicked: close()
                }
            }
            
            // Search box
            Rectangle {
                width: parent.width - units.gu(4)
                height: units.gu(5)
                anchors.horizontalCenter: parent.horizontalCenter
                radius: units.gu(0.5)
                color: Theme.palette.normal.base
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(1)
                    anchors.rightMargin: units.gu(1)
                    spacing: units.gu(1)
                    
                    Icon {
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    TextField {
                        id: searchField
                        width: parent.width - units.gu(4)
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: i18n.tr("Search friends...")
                        onTextChanged: searchQuery = text
                    }
                }
            }
            
            // Description
            Label {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Select a friend to start a conversation")
                fontSize: "small"
                color: Theme.palette.normal.backgroundSecondaryText
            }
            
            // Divider
            Rectangle {
                width: parent.width - units.gu(4)
                anchors.horizontalCenter: parent.horizontalCenter
                height: units.dp(1)
                color: Theme.palette.normal.base
            }
            
            // Loading state
            Item {
                width: parent.width
                height: units.gu(15)
                visible: loading
                
                ActivityIndicator {
                    anchors.centerIn: parent
                    running: loading
                }
            }
            
            // Friends list
            ListView {
                id: friendsList
                width: parent.width
                height: Math.min(contentHeight, units.gu(40))
                clip: true
                visible: !loading && filteredFriends.length > 0
                cacheBuffer: units.gu(20)  // Performance optimization
                
                model: filteredFriends
                
                delegate: Rectangle {
                    width: friendsList.width
                    height: units.gu(6)
                    color: mouseArea.pressed ? Theme.palette.normal.base : "transparent"
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: units.gu(2)
                        anchors.rightMargin: units.gu(2)
                        spacing: units.gu(1.5)
                        
                        Components.Avatar {
                            width: units.gu(4.5)
                            height: units.gu(4.5)
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.displayName || modelData.username || ""
                            source: modelData.profilePicture ? 
                                    SerchatAPI.apiBaseUrl + modelData.profilePicture : ""
                            showStatus: true
                            status: modelData.customStatus ? 
                                    (modelData.customStatus.status || "online") : "online"
                        }
                        
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: units.gu(0.2)
                            
                            Label {
                                text: modelData.displayName || modelData.username || i18n.tr("Unknown")
                                fontSize: "small"
                                font.bold: true
                            }
                            
                            Label {
                                text: "@" + (modelData.username || "")
                                fontSize: "x-small"
                                color: Theme.palette.normal.backgroundSecondaryText
                                visible: modelData.displayName && modelData.username
                            }
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        onClicked: {
                            var recipientId = modelData._id || modelData.id
                            var recipientName = modelData.displayName || modelData.username
                            var recipientAvatar = modelData.profilePicture ? 
                                                  SerchatAPI.apiBaseUrl + modelData.profilePicture : ""
                            conversationStarted(recipientId, recipientName, recipientAvatar)
                            close()
                        }
                    }
                }
            }
            
            // Empty state
            Item {
                width: parent.width
                height: units.gu(15)
                visible: !loading && filteredFriends.length === 0
                
                Column {
                    anchors.centerIn: parent
                    spacing: units.gu(1)
                    
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(5)
                        height: units.gu(5)
                        name: "contact"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchQuery ? 
                              i18n.tr("No friends found") : 
                              i18n.tr("No friends yet")
                        fontSize: "small"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                    
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchQuery ? 
                              i18n.tr("Try a different search term") :
                              i18n.tr("Add friends to start messaging!")
                        fontSize: "x-small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        visible: !searchQuery
                    }
                }
            }
            
            // Bottom padding
            Item {
                width: parent.width
                height: units.gu(1)
            }
        }
    }
    
    function open(friendsList) {
        if (friendsList && friendsList.length > 0) {
            friends = friendsList
        } else {
            // Fetch friends from API if not provided
            loading = true
            SerchatAPI.getFriends(false)  // Don't use cache to get fresh data
        }
        searchQuery = ""
        searchField.text = ""
        opened = true
        searchField.forceActiveFocus()
    }
    
    // Handle friends fetched signal
    Connections {
        target: SerchatAPI
        
        onFriendsFetched: {
            if (opened) {
                createDMDialog.friends = friends  // Signal parameter is 'friends'
                loading = false
            }
        }
        
        onFriendsFetchFailed: {
            if (opened) {
                loading = false
            }
        }
    }
    
    function close() {
        opened = false
        closed()
    }
}
