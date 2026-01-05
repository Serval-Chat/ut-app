import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: editProfilePage
    
    property var userProfile: ({})
    property bool saving: false
    property var requests: []
    property int completedRequests: 0
    property var failedRequests: []
    
    header: PageHeader {
        id: header
        title: i18n.tr("Edit Profile")
        
        leadingActionBar.actions: [
            Action {
                iconName: "close"
                text: i18n.tr("Cancel")
                onTriggered: pageStack.pop()
            }
        ]
        
        trailingActionBar.actions: [
            Action {
                iconName: "ok"
                text: i18n.tr("Save")
                enabled: !saving
                onTriggered: saveProfile()
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
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: units.gu(2)
            }
            spacing: units.gu(2)
            
            // Avatar section
            Item {
                width: parent.width
                height: units.gu(14)
                
                Components.Avatar {
                    id: avatarPreview
                    anchors.centerIn: parent
                    width: units.gu(12)
                    height: units.gu(12)
                    name: displayNameField.text || userProfile.username || ""
                    source: userProfile.profilePicture ? 
                            (SerchatAPI.apiBaseUrl + userProfile.profilePicture) : ""
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: units.dp(2)
                        border.color: Theme.palette.normal.base
                    }
                    
                    // Change avatar overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.5)
                        opacity: avatarMouseArea.containsMouse ? 1 : 0
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: units.gu(0.5)
                            
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: units.gu(3)
                                height: units.gu(3)
                                name: "camera-app-symbolic"
                                color: "white"
                            }
                            
                            Label {
                                text: i18n.tr("Change")
                                fontSize: "small"
                                color: "white"
                            }
                        }
                    }
                    
                    MouseArea {
                        id: avatarMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            // TODO: Open image picker for avatar
                            errorLabel.text = "Image picker not yet implemented"
                        }
                    }
                }
            }
            
            // Display name
            Label {
                text: i18n.tr("Display Name")
                fontSize: "small"
                font.bold: true
            }
            
            TextField {
                id: displayNameField
                width: parent.width
                text: userProfile.displayName || ""
                placeholderText: i18n.tr("How you want to be known")
            }
            
            // Username (read-only for now)
            Label {
                text: i18n.tr("Username")
                fontSize: "small"
                font.bold: true
            }
            
            TextField {
                id: usernameField
                width: parent.width
                text: userProfile.username || ""
                enabled: false
                placeholderText: i18n.tr("Your unique username")
            }
            
            Label {
                text: i18n.tr("Username changes are not yet supported")
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
            }
            
            // Pronouns
            Label {
                text: i18n.tr("Pronouns")
                fontSize: "small"
                font.bold: true
            }
            
            TextField {
                id: pronounsField
                width: parent.width
                text: userProfile.pronouns || ""
                placeholderText: i18n.tr("e.g., they/them, she/her, he/him")
            }
            
            // Bio
            Label {
                text: i18n.tr("About Me")
                fontSize: "small"
                font.bold: true
            }
            
            TextArea {
                id: bioField
                width: parent.width
                height: units.gu(12)
                text: userProfile.bio || ""
                placeholderText: i18n.tr("Tell others about yourself")
            }
            
            Label {
                text: i18n.tr("You can use markdown formatting")
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
            }
            
            // Banner section
            Label {
                text: i18n.tr("Profile Banner")
                fontSize: "small"
                font.bold: true
            }
            
            Rectangle {
                width: parent.width
                height: units.gu(12)
                radius: units.gu(1)
                color: getBannerColor()
                
                Image {
                    anchors.fill: parent
                    source: userProfile.banner ? 
                            (SerchatAPI.apiBaseUrl + "/api/v1/user/banner/" + userProfile.banner) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: units.gu(1)
                        color: "transparent"
                    }
                }
                
                // Change banner overlay
                Rectangle {
                    anchors.fill: parent
                    radius: units.gu(1)
                    color: Qt.rgba(0, 0, 0, 0.3)
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: units.gu(1)
                        
                        Icon {
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: "camera-app-symbolic"
                            color: "white"
                        }
                        
                        Label {
                            text: i18n.tr("Change Banner")
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // TODO: Open image picker for banner
                        errorLabel.text = "Image picker not yet implemented"
                    }
                }
            }
            
            // Error message
            Label {
                id: errorLabel
                text: ""
                color: LomiriColors.red
                visible: text !== ""
                wrapMode: Text.Wrap
                width: parent.width
            }
        }
    }
    
    // Saving overlay
    Components.LoadingOverlay {
        visible: saving
        message: i18n.tr("Saving...")
    }
    
    function getBannerColor() {
        return Components.ColorUtils.colorFromString(userProfile.username)
    }
    
    function saveProfile() {
        saving = true
        errorLabel.text = ""
        
        var requests = []
        var hasChanges = false
        
        // Check for changes and queue API calls
        if (displayNameField.text !== (userProfile.displayName || "")) {
            requests.push({
                type: "displayName",
                requestId: SerchatAPI.updateDisplayName(displayNameField.text)
            })
            hasChanges = true
        }
        
        if (pronounsField.text !== (userProfile.pronouns || "")) {
            requests.push({
                type: "pronouns", 
                requestId: SerchatAPI.updatePronouns(pronounsField.text)
            })
            hasChanges = true
        }
        
        if (bioField.text !== (userProfile.bio || "")) {
            requests.push({
                type: "bio",
                requestId: SerchatAPI.updateBio(bioField.text)
            })
            hasChanges = true
        }
        
        if (!hasChanges) {
            saving = false
            errorLabel.text = "No changes to save"
            return
        }
        
        // Store requests for tracking completion
        page.requests = requests
        page.completedRequests = 0
        page.failedRequests = []
        
        // Connect to signals
        var successConnection = SerchatAPI.profileUpdateSuccess.connect(onProfileUpdateSuccess)
        var failureConnection = SerchatAPI.profileUpdateFailed.connect(onProfileUpdateFailed)
        
        // Store connections for cleanup
        page.successConnection = successConnection
        page.failureConnection = failureConnection
    }
    
    function onProfileUpdateSuccess(requestId) {
        page.completedRequests++
        
        // Check if all requests completed
        if (page.completedRequests >= page.requests.length) {
            cleanupConnections()
            saving = false
            
            if (page.failedRequests.length === 0) {
                // All successful
                pageStack.pop()
            } else {
                // Some failed
                errorLabel.text = "Some updates failed: " + page.failedRequests.join(", ")
            }
        }
    }
    
    function onProfileUpdateFailed(requestId, error) {
        page.failedRequests.push(error)
        page.completedRequests++
        
        // Check if all requests completed
        if (page.completedRequests >= page.requests.length) {
            cleanupConnections()
            saving = false
            
            if (page.failedRequests.length === page.requests.length) {
                // All failed
                errorLabel.text = "All updates failed: " + page.failedRequests.join(", ")
            } else {
                // Some failed
                errorLabel.text = "Some updates failed: " + page.failedRequests.join(", ")
            }
        }
    }
    
    function cleanupConnections() {
        if (page.successConnection) {
            SerchatAPI.profileUpdateSuccess.disconnect(page.successConnection)
            page.successConnection = null
        }
        if (page.failureConnection) {
            SerchatAPI.profileUpdateFailed.disconnect(page.failureConnection)
            page.failureConnection = null
        }
    }
}
