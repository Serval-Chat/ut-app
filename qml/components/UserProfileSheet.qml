import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * UserProfileSheet - Bottom sheet popup showing user profile summary
 * 
 * Shows a condensed profile view that slides up from the bottom
 * with quick actions and option to view full profile.
 */
Item {
    id: userProfileSheet
    
    // The user ID to display
    property string userId: ""
    property var userProfile: ({})
    property bool loading: false
    property bool isOwnProfile: false
    
    // Whether the sheet is currently visible
    property bool opened: false
    
    // Request tracking
    property int profileRequestId: -1
    
    signal viewFullProfileClicked(string userId)
    signal sendMessageClicked(string userId)
    signal addFriendClicked(string userId)
    signal closed()
    
    // Cover the full parent area
    anchors.fill: parent
    visible: opened
    z: 1000
    
    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
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
    
    // Sheet container
    Rectangle {
        id: sheet
        width: parent.width
        height: Math.min(sheetContent.height + units.gu(2), parent.height * 0.7)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: opened ? 0 : -height
        radius: units.gu(2)
        color: Theme.palette.normal.background
        
        // Top rounded corners only
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
        }
        
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        
        // Handle bar
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: units.gu(1)
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(5)
            height: units.gu(0.5)
            radius: height / 2
            color: Theme.palette.normal.base
        }
        
        // Sheet content
        Column {
            id: sheetContent
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: units.gu(2.5)
            spacing: units.gu(2)
            
            // Loading state
            Item {
                width: parent.width
                height: units.gu(20)
                visible: loading
                
                ActivityIndicator {
                    anchors.centerIn: parent
                    running: loading
                }
            }
            
            // Profile content
            Column {
                width: parent.width
                spacing: units.gu(1.5)
                visible: !loading
                
                // Avatar and basic info
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(2)
                    
                    // Large avatar
                    Components.Avatar {
                        id: avatar
                        width: units.gu(10)
                        height: units.gu(10)
                        name: userProfile.displayName || userProfile.username || ""
                        source: userProfile.profilePicture ? 
                                (SerchatAPI.apiBaseUrl + userProfile.profilePicture) : ""
                        showStatus: true
                        status: userProfile.customStatus ? 
                                (userProfile.customStatus.status || "online") : "online"
                    }
                    
                    // Name and info
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.5)
                        width: userProfileSheet.width - avatar.width - units.gu(8)
                        
                        // Display name
                        Label {
                            text: userProfile.displayName || userProfile.username || i18n.tr("Unknown User")
                            fontSize: "large"
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        // Username
                        Label {
                            text: "@" + (userProfile.username || "")
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            visible: userProfile.username !== undefined
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        // Pronouns
                        Label {
                            text: userProfile.pronouns || ""
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            visible: userProfile.pronouns !== undefined && userProfile.pronouns !== ""
                        }
                    }
                }
                
                // Custom status
                Rectangle {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: statusRow.height + units.gu(2)
                    radius: units.gu(1)
                    color: Theme.palette.normal.base
                    visible: userProfile.customStatus !== undefined && userProfile.customStatus !== null && 
                             userProfile.customStatus.text !== undefined && userProfile.customStatus.text !== ""
                    
                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: units.gu(1)
                        width: parent.width - units.gu(2)
                        
                        Label {
                            text: userProfile.customStatus ? (userProfile.customStatus.emoji || "💬") : ""
                            fontSize: "medium"
                        }
                        
                        Label {
                            text: userProfile.customStatus ? (userProfile.customStatus.text || "") : ""
                            fontSize: "small"
                            color: Theme.palette.normal.baseText
                            wrapMode: Text.Wrap
                            width: parent.width - units.gu(5)
                        }
                    }
                }
                
                // Badges
                Flow {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(0.5)
                    visible: userProfile.badges !== undefined && userProfile.badges !== null && userProfile.badges.length > 0
                    
                    Repeater {
                        model: userProfile.badges || []
                        
                        Rectangle {
                            width: badgeRow.width + units.gu(1.5)
                            height: units.gu(3)
                            radius: units.gu(0.5)
                            color: modelData.color || Theme.palette.normal.base
                            
                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: units.gu(0.5)
                                
                                Label {
                                    text: modelData.icon || ""
                                    fontSize: "small"
                                }
                                
                                Label {
                                    text: modelData.name || ""
                                    fontSize: "x-small"
                                    color: "white"
                                }
                            }
                        }
                    }
                }
                
                // Bio preview
                Rectangle {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: bioColumn.height + units.gu(2)
                    radius: units.gu(1)
                    color: Theme.palette.normal.base
                    visible: userProfile.bio !== undefined && userProfile.bio !== null && userProfile.bio !== ""
                    
                    Column {
                        id: bioColumn
                        width: parent.width - units.gu(2)
                        anchors.centerIn: parent
                        spacing: units.gu(0.5)
                        
                        Label {
                            text: i18n.tr("About Me")
                            fontSize: "x-small"
                            font.bold: true
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                        
                        Label {
                            text: userProfile.bio ? 
                                  (userProfile.bio.length > 150 ? 
                                   userProfile.bio.substring(0, 150) + "..." : userProfile.bio) : ""
                            fontSize: "small"
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                }
                
                // Divider
                Rectangle {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.dp(1)
                    color: Theme.palette.normal.base
                }
                
                // Action buttons
                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)
                    
                    // View Full Profile button
                    Button {
                        width: parent.width
                        text: i18n.tr("View Full Profile")
                        color: LomiriColors.blue
                        onClicked: {
                            close()
                            viewFullProfileClicked(userId)
                        }
                    }
                    
                    // Send Message button (not for own profile)
                    Button {
                        width: parent.width
                        text: i18n.tr("Send Message")
                        visible: !isOwnProfile
                        onClicked: {
                            close()
                            sendMessageClicked(userId)
                        }
                    }
                    
                    // Add Friend button (not for own profile)
                    Button {
                        width: parent.width
                        text: i18n.tr("Add Friend")
                        visible: !isOwnProfile && !isFriend()
                        color: Theme.palette.normal.positive
                        onClicked: {
                            close()
                            addFriendClicked(userId)
                        }
                    }
                }
                
                // Bottom padding
                Item {
                    width: parent.width
                    height: units.gu(2)
                }
            }
        }
        
        // Drag to dismiss
        MouseArea {
            id: dragArea
            anchors.fill: parent
            propagateComposedEvents: true
            
            property real startY: 0
            property real currentOffset: 0
            
            onPressed: {
                startY = mouse.y
                currentOffset = 0
            }
            
            onPositionChanged: {
                currentOffset = mouse.y - startY
                if (currentOffset > 0) {
                    sheet.anchors.bottomMargin = -currentOffset
                }
            }
            
            onReleased: {
                if (currentOffset > units.gu(10)) {
                    close()
                } else {
                    sheet.anchors.bottomMargin = 0
                }
            }
            
            onClicked: mouse.accepted = false
        }
    }
    
    // Open the sheet for a user
    function open(targetUserId, isOwn) {
        userId = targetUserId
        isOwnProfile = isOwn || false
        userProfile = {}
        loading = true
        opened = true
        
        // Fetch the profile
        profileRequestId = SerchatAPI.getProfile(userId)
    }
    
    // Close the sheet
    function close() {
        opened = false
        closed()
    }
    
    // Check if user is a friend (TODO: implement properly)
    function isFriend() {
        // TODO: Check friendship status from API
        return false
    }
    
    // Handle profile fetched
    Connections {
        target: SerchatAPI
        
        onProfileFetched: {
            if (requestId === profileRequestId) {
                userProfile = profile
                loading = false
            }
        }
        
        onProfileFetchFailed: {
            if (requestId === profileRequestId) {
                loading = false
                // Show error state
                userProfile = {
                    username: i18n.tr("Error"),
                    displayName: i18n.tr("Could not load profile")
                }
            }
        }
    }
}
