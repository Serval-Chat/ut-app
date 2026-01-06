import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: profilePage
    
    property string userId: ""
    property var userProfile: ({})
    property bool loading: true
    property bool isOwnProfile: false
    property bool isFriend: false
    
    // Generate banner color from user identity
    function getBannerColor() {
        var identifier = userProfile.displayName || userProfile.username || userId || ""
        return Components.ColorUtils.colorFromString(identifier)
    }
    
    header: PageHeader {
        id: header
        title: userProfile.displayName || userProfile.username || i18n.tr("Profile")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
        
        trailingActionBar.actions: [
            Action {
                iconName: "edit"
                text: i18n.tr("Edit Profile")
                visible: isOwnProfile
                onTriggered: {
                    pageStack.push(Qt.resolvedUrl("EditProfilePage.qml"), {
                        userProfile: userProfile
                    })
                }
            },
            Action {
                iconName: "list-remove"
                text: i18n.tr("Remove Friend")
                visible: isFriend && !isOwnProfile
                onTriggered: {
                    PopupUtils.open(removeFriendDialogComponent)
                }
            },
            Action {
                iconName: "compose"
                text: i18n.tr("Message")
                visible: !isOwnProfile
                onTriggered: {
                    // Navigate back and open DM with user
                    var recipientName = userProfile.displayName || userProfile.username || ""
                    var recipientAvatar = userProfile.profilePicture ? 
                                         (SerchatAPI.apiBaseUrl + userProfile.profilePicture) : ""
                    pageStack.pop()
                    // The HomePage will need to listen for this signal
                    // For now, we use a direct property approach
                    if (pageStack.currentItem && pageStack.currentItem.openDMWithUser) {
                        pageStack.currentItem.openDMWithUser(userId, recipientName, recipientAvatar)
                    }
                }
            }
        ]
    }
    
    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: contentColumn.height + units.gu(4)
        clip: true
        
        Column {
            id: contentColumn
            width: parent.width
            spacing: 0
            
            // Banner area
            Rectangle {
                width: parent.width
                height: units.gu(15)
                color: getBannerColor()
                
                Image {
                    anchors.fill: parent
                    source: userProfile.banner ? 
                            (SerchatAPI.apiBaseUrl + userProfile.banner) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }
            
            // Profile info area
            Rectangle {
                width: parent.width
                height: profileInfoColumn.height + units.gu(10)  // Extra space for overlapping avatar
                color: Theme.palette.normal.background
                
                // Avatar (overlapping banner)
                Components.Avatar {
                    id: avatar
                    width: units.gu(12)
                    height: units.gu(12)
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(2)
                        top: parent.top
                        topMargin: -units.gu(6)
                    }
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
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: units.gu(0.5)
                        border.color: Theme.palette.normal.background
                    }
                }
                
                Column {
                    id: profileInfoColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: avatar.bottom
                        topMargin: units.gu(1)
                        leftMargin: units.gu(2)
                        rightMargin: units.gu(2)
                    }
                    spacing: units.gu(1)
                    
                    // Display name
                    Label {
                        text: userProfile.displayName || userProfile.username || i18n.tr("Unknown User")
                        fontSize: "x-large"
                        font.bold: true
                    }
                    
                    // Username
                    Label {
                        text: "@" + (userProfile.username || "")
                        fontSize: "small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        visible: userProfile.username !== undefined
                    }
                    
                    // Pronouns
                    Label {
                        text: userProfile.pronouns || ""
                        fontSize: "small"
                        color: Theme.palette.normal.backgroundSecondaryText
                        visible: userProfile.pronouns !== undefined && userProfile.pronouns !== ""
                    }
                    
                    // Custom status
                    Row {
                        spacing: units.gu(0.5)
                        visible: userProfile.customStatus !== undefined && userProfile.customStatus !== null &&
                                 userProfile.customStatus.text !== undefined && userProfile.customStatus.text !== ""
                        
                        Label {
                            text: userProfile.customStatus ? (userProfile.customStatus.emoji || "") : ""
                            fontSize: "small"
                        }
                        
                        Label {
                            text: userProfile.customStatus ? (userProfile.customStatus.text || "") : ""
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                        }
                    }
                    
                    // Badges
                    Flow {
                        width: parent.width
                        spacing: units.gu(0.5)
                        visible: userProfile.badges !== undefined && userProfile.badges !== null && userProfile.badges.length > 0
                        
                        Repeater {
                            model: userProfile.badges || []
                            
                            Components.BadgeLike {
                                height: units.gu(3)
                                radius: units.gu(0.5)
                                badgeColor: modelData.color || Theme.palette.normal.base

                                icon: modelData.icon || ""
                                name: modelData.name || ""
                            }
                        }
                    }
                }
            }
            
            // Divider
            Rectangle {
                width: parent.width
                height: units.gu(1)
                color: Theme.palette.normal.base
            }
            
            // About Me section
            Rectangle {
                width: parent.width
                height: aboutColumn.height + units.gu(3)
                color: Theme.palette.normal.background
                visible: userProfile.bio !== undefined && userProfile.bio !== null && userProfile.bio !== ""
                
                Column {
                    id: aboutColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(2)
                    }
                    spacing: units.gu(1)
                    
                    Label {
                        text: i18n.tr("About Me")
                        fontSize: "medium"
                        font.bold: true
                    }
                    
                    Label {
                        text: userProfile.bio || ""
                        fontSize: "small"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }
            
            // Member since
            Rectangle {
                width: parent.width
                height: memberColumn.height + units.gu(3)
                color: Theme.palette.normal.background
                
                Column {
                    id: memberColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(2)
                    }
                    spacing: units.gu(1)
                    
                    Label {
                        text: i18n.tr("Member Since")
                        fontSize: "medium"
                        font.bold: true
                    }
                    
                    Label {
                        text: userProfile.createdAt ? 
                              formatDate(userProfile.createdAt) : 
                              i18n.tr("Unknown")
                        fontSize: "small"
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
            
            // Action buttons for other users
            Rectangle {
                width: parent.width
                height: actionColumn.height + units.gu(4)
                color: Theme.palette.normal.background
                visible: !isOwnProfile
                
                Column {
                    id: actionColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: units.gu(2)
                    }
                    spacing: units.gu(1)
                    
                    Button {
                        width: parent.width
                        text: i18n.tr("Send Friend Request")
                        color: LomiriColors.blue
                        visible: !isFriend
                        onClicked: {
                            SerchatAPI.sendFriendRequest(userProfile.username)
                        }
                    }
                    
                    Button {
                        width: parent.width
                        text: i18n.tr("Block User")
                        color: Theme.palette.normal.base
                        visible: !isFriend
                    }
                }
            }
        }
    }
    
    // Loading overlay
    Components.LoadingOverlay {
        visible: loading
    }
    
    function checkIfFriend() {
        if (isOwnProfile || !userId || userId === "me") {
            isFriend = false
            return
        }
        
        // Check if userId is in the friends list
        var friendsModel = SerchatAPI.friendsModel
        for (var i = 0; i < friendsModel.count; i++) {
            var friend = friendsModel.getAt(i)
            if (friend._id === userId) {
                isFriend = true
                return
            }
        }
        isFriend = false
    }
    
    function formatDate(dateString) {
        var date = new Date(dateString)
        return date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    }
    
    Connections {
        target: SerchatAPI
        
        onProfileFetched: {
            if (requestId === profileRequestId) {
                userProfile = profile
                loading = false
                checkIfFriend()
            }
        }
        
        onProfileFetchFailed: {
            if (requestId === profileRequestId) {
                loading = false
                console.log("Failed to load profile:", error)
            }
        }
        
        onMyProfileFetched: {
            if (userId === "me" || userId === profile.id) {
                userProfile = profile
                isOwnProfile = true
                loading = false
                checkIfFriend()
            }
        }
        
        onFriendsFetched: {
            checkIfFriend()
        }
    }
    
    // Remove friend confirmation dialog component
    Component {
        id: removeFriendDialogComponent
        
        Dialog {
            id: removeFriendDialog
            title: i18n.tr("Remove Friend")
            text: i18n.tr("Are you sure you want to remove %1 from your friends?").arg(userProfile.displayName || userProfile.username || i18n.tr("this user"))
            
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(removeFriendDialog)
            }
            
            Button {
                text: i18n.tr("Remove")
                color: LomiriColors.red
                onClicked: {
                    PopupUtils.close(removeFriendDialog)
                    SerchatAPI.removeFriend(userId)
                }
            }
        }
    }
    
    Connections {
        target: SerchatAPI
        
        onFriendRequestSent: {
            // Refresh friends list to update UI
            SerchatAPI.getFriends()
        }
        
        onFriendRequestSendFailed: {
            // TODO: Show error message
            console.log("Failed to send friend request:", error)
        }
        
        onFriendRemovedApi: {
            // Refresh friends list and update UI
            SerchatAPI.getFriends()
            checkIfFriend()
        }
        
        onFriendRemoveFailed: {
            // TODO: Show error message
            console.log("Failed to remove friend:", error)
        }
    }
    
    property int profileRequestId: -1
    
    Component.onCompleted: {
        if (userId === "me" || userId === "") {
            isOwnProfile = true
            SerchatAPI.getMyProfile()
        } else {
            profileRequestId = SerchatAPI.getProfile(userId)
            // Fetch friends to check friendship status
            SerchatAPI.getFriends()
        }
    }
}
