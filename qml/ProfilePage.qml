import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: profilePage
    
    property string userId: ""
    property var userProfile: ({})
    property bool loading: true
    property bool isOwnProfile: false
    
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
                iconName: "compose"
                text: i18n.tr("Message")
                visible: !isOwnProfile
                onTriggered: {
                    // TODO: Open DM with user
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
                    status: "online"  // TODO: Get actual status
                    
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
                        // TODO: Check if already friends
                    }
                    
                    Button {
                        width: parent.width
                        text: i18n.tr("Block User")
                        color: Theme.palette.normal.base
                    }
                }
            }
        }
    }
    
    // Loading overlay
    Rectangle {
        anchors.fill: parent
        color: Theme.palette.normal.background
        visible: loading
        
        ActivityIndicator {
            anchors.centerIn: parent
            running: loading
        }
    }
    
    function getBannerColor() {
        // Generate a color from the username
        var name = userProfile.username || "user"
        var colors = ["#7289da", "#43b581", "#faa61a", "#f04747", "#9b59b6"]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        return colors[Math.abs(hash) % colors.length]
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
            }
        }
    }
    
    property int profileRequestId: -1
    
    Component.onCompleted: {
        if (userId === "me" || userId === "") {
            isOwnProfile = true
            SerchatAPI.getMyProfile()
        } else {
            profileRequestId = SerchatAPI.getProfile(userId)
        }
    }
}
