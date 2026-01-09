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
 * 
 * When opened from a server context (serverId is set), also displays
 * the user's roles in that server. Handles gracefully when user is
 * not a member (e.g., old mentions from users who left).
 */
Item {
    id: userProfileSheet
    
    // The user ID to display
    property string userId: ""
    property var userProfile: ({})
    property bool loading: false
    
    // Server context (optional) - when set, shows server-specific info like roles
    property string serverId: ""
    
    // Server member cache version for reactive updates
    property int serverMemberCacheVersion: SerchatAPI.serverMemberCache ? SerchatAPI.serverMemberCache.version : 0
    
    // Get member roles when in server context
    property var memberRoles: {
        // Depend on cache version for reactivity
        var v = serverMemberCacheVersion
        if (!serverId || !userId) return []
        return SerchatAPI.serverMemberCache.getMemberRoleObjects(serverId, userId) || []
    }
    
    // Check if user is a member of the server (has member data cached or being fetched)
    property bool isServerMember: {
        var v = serverMemberCacheVersion
        if (!serverId || !userId) return false
        // hasMember returns true only if cached, not if fetch is pending
        return SerchatAPI.serverMemberCache.hasMember(serverId, userId)
    }
    
    // Whether this is the current user's own profile
    readonly property bool isOwnProfile: userId === SerchatAPI.currentUserId
    
    // Whether the user is a friend (reactive to friends model changes)
    property bool isFriend: calculateIsFriend()
    
    // Whether the sheet is currently visible
    property bool opened: false

    // Request tracking
    property int profileRequestId: -1
    
    onUserIdChanged: {
        isFriend = calculateIsFriend()
    }
    
    signal viewFullProfileClicked(string userId, string serverId)
    signal sendMessageClicked(string userId)
    signal addFriendClicked(string userId)
    signal removeFriendClicked(string userId)
    signal editProfileClicked()
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
        height: Math.min(contentFlickable.contentHeight + units.gu(2.5), parent.height * 0.8)
        radius: units.gu(2)
        color: Theme.palette.normal.background
        
        y: parent.height - (opened ? height : 0)
        
        Behavior on y {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        
        // Top rounded corners only
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
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
        
        // Scrollable content area
        Flickable {
            id: contentFlickable
            anchors.top: parent.top
            anchors.topMargin: units.gu(2.5)
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            contentHeight: sheetContent.height
            clip: true
            
            // Sheet content
            Column {
                id: sheetContent
                width: parent.width
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
                            status: {
                                var username = userProfile.username || ""
                                if (!SerchatAPI.isUserOnline(username)) {
                                    return "offline"
                                }
                                return userProfile.customStatus ? 
                                    (userProfile.customStatus.status || "online") : "online"
                            }
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
                            
                            BadgeLike {
                                height: units.gu(3)
                                radius: units.gu(0.5)
                                badgeColor: modelData.color || Theme.palette.normal.base

                                icon: modelData.icon || ""
                                name: modelData.name || ""
                            }
                        }
                    }
                    
                    // Server Roles (only shown when in server context and user is a member)
                    Rectangle {
                        id: rolesSection
                        width: parent.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: rolesColumn.height + units.gu(2)
                        radius: units.gu(1)
                        color: Theme.palette.normal.base
                        visible: serverId !== "" && memberRoles.length > 0
                        
                        Column {
                            id: rolesColumn
                            width: parent.width - units.gu(2)
                            anchors.centerIn: parent
                            spacing: units.gu(0.5)
                            
                            Label {
                                text: i18n.tr("Roles")
                                fontSize: "x-small"
                                font.bold: true
                                color: Theme.palette.normal.backgroundSecondaryText
                            }
                            
                            Flow {
                                width: parent.width
                                spacing: units.gu(0.5)
                                
                                Repeater {
                                    model: memberRoles
                                    
                                    Components.BadgeLike {
                                        height: units.gu(3)
                                        radius: units.gu(0.5)
                                        badgeColor: modelData.color || modelData.startColor || Theme.palette.normal.base
                                        name: modelData.name || i18n.tr("Unknown Role")
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
                            
                            Components.MarkdownText {
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
                        
                        // View Full Profile button (not for own profile)
                        Button {
                            width: parent.width
                            text: i18n.tr("View Full Profile")
                            color: LomiriColors.blue
                            visible: !isOwnProfile
                            onClicked: {
                                close()
                                viewFullProfileClicked(userId, serverId)
                            }
                        }
                        
                        // Edit Profile button (only for own profile)
                        Button {
                            width: parent.width
                            text: i18n.tr("Edit Profile")
                            color: LomiriColors.blue
                            visible: isOwnProfile
                            onClicked: {
                                close()
                                editProfileClicked()
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
                        
                        // Add Friend button (not for own profile, only when not friends)
                        Button {
                            width: parent.width
                            text: i18n.tr("Add Friend")
                            visible: !isOwnProfile && !isFriend
                            color: Theme.palette.normal.positive
                            onClicked: {
                                close()
                                addFriendClicked(userId)
                            }
                        }
                        
                        // Remove Friend button (not for own profile, only when friends)
                        Button {
                            width: parent.width
                            text: i18n.tr("Remove Friend")
                            visible: !isOwnProfile && isFriend
                            color: LomiriColors.red
                            onClicked: {
                                close()
                                removeFriendClicked(userId)
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
    
    // Open the sheet for a user, optionally in server context
    // When targetServerId is provided, server-specific info like roles will be shown
    function open(targetUserId, targetServerId) {
        userId = targetUserId
        serverId = targetServerId || ""
        userProfile = {}
        loading = true
        opened = true
        
        // Fetch the profile
        profileRequestId = SerchatAPI.getProfile(userId)
        
        // If in server context, ensure we have member data cached for role display
        // This will auto-fetch if not cached; if user is not a member, roles will be empty
        if (serverId && userId) {
            SerchatAPI.serverMemberCache.fetchMember(serverId, userId)
        }
    }
    
    // Close the sheet
    function close() {
        opened = false
        serverId = ""  // Clear server context on close
        closed()
    }
    
    // Check if user is a friend
    function calculateIsFriend() {
        if (isOwnProfile || !userId) {
            return false
        }
        
        // Check if userId is in the friends list
        var friendsModel = SerchatAPI.friendsModel
        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.getAt(i)
            if (friend._id === userId) {
                return true
            }
        }
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
        
        onFriendsFetched: {
            // Update button visibility when friends list changes
            // This ensures the sheet stays in sync if friends are added/removed while open
            isFriend = calculateIsFriend()
        }
        
        onFriendAdded: {
            isFriend = calculateIsFriend()
        }
        
        onFriendRemoved: {
            isFriend = calculateIsFriend()
        }
    }
}
