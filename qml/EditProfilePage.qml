import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Lomiri.Content 1.1

import SerchatAPI 1.0
import "components" as Components

Page {
    id: editProfilePage
    
    property var userProfile: ({})
    property bool saving: false
    property var requests: []
    property int completedRequests: 0
    property var failedRequests: []
    property var activeTransfer: null
    property string imagePickerTarget: "" // "avatar" or "banner"
    property var successConnection: null
    property var failureConnection: null
    
    // Buffered changes
    property string bufferedAvatarPath: ""
    property string bufferedBannerPath: ""
    
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
                    source: bufferedAvatarPath ? ("file://" + bufferedAvatarPath) :
                            (userProfile.profilePicture ? 
                            (SerchatAPI.apiBaseUrl + userProfile.profilePicture) : "")
                    
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
                            imagePickerTarget = "avatar"
                            activeTransfer = picturePicker.request()
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
                    source: bufferedBannerPath ? ("file://" + bufferedBannerPath) :
                            (userProfile.banner ? 
                            (SerchatAPI.apiBaseUrl + "/api/v1/user/banner/" + userProfile.banner) : "")
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
                        imagePickerTarget = "banner"
                        activeTransfer = picturePicker.request()
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
    
    // ContentHub integration for image picking
    ContentPeer {
        id: picturePicker
        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        selectionType: ContentTransfer.Single
    }
    
    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: editProfilePage.activeTransfer
    }
    
    Connections {
        target: editProfilePage.activeTransfer
        onStateChanged: {
            if (editProfilePage.activeTransfer.state === ContentTransfer.Charged) {
                if (editProfilePage.activeTransfer.items.length > 0) {
                    var item = editProfilePage.activeTransfer.items[0]
                    var filePath = String(item.url).replace("file://", "")
                    handleImageSelected(filePath)
                }
            }
        }
    }
    
    function getBannerColor() {
        return Components.ColorUtils.colorFromString(userProfile.username)
    }
    
    function saveProfile() {
        saving = true
        errorLabel.text = ""
        
        // Connect to signals BEFORE making API calls
        var successConnection = SerchatAPI.profileUpdateSuccess.connect(onProfileUpdateSuccess)
        var failureConnection = SerchatAPI.profileUpdateFailed.connect(onProfileUpdateFailed)
        
        // Store connections for cleanup
        editProfilePage.successConnection = successConnection
        editProfilePage.failureConnection = failureConnection
        
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
        
        // Check for buffered image uploads
        if (bufferedAvatarPath) {
            requests.push({
                type: "avatar",
                requestId: SerchatAPI.uploadProfilePicture(bufferedAvatarPath)
            })
            hasChanges = true
        }
        
        if (bufferedBannerPath) {
            requests.push({
                type: "banner",
                requestId: SerchatAPI.uploadBanner(bufferedBannerPath)
            })
            hasChanges = true
        }
        
        if (!hasChanges) {
            cleanupConnections()
            saving = false
            errorLabel.text = "No changes to save"
            return
        }
        
        // Store requests for tracking completion
        editProfilePage.requests = requests
        editProfilePage.completedRequests = 0
        editProfilePage.failedRequests = []
    }
    
    function onProfileUpdateSuccess(requestId) {
        editProfilePage.completedRequests++
        
        // Check if all requests completed
        if (editProfilePage.completedRequests >= editProfilePage.requests.length) {
            cleanupConnections()
            
            if (editProfilePage.failedRequests.length === 0) {
                // All successful - refresh profile before closing
                SerchatAPI.getUserProfile()
                saving = false
                pageStack.pop()
            } else {
                // Some failed
                saving = false
                errorLabel.text = "Some updates failed: " + editProfilePage.failedRequests.join(", ")
            }
        }
    }
    
    function onProfileUpdateFailed(requestId, error) {
        editProfilePage.failedRequests.push(error)
        editProfilePage.completedRequests++
        
        // Check if all requests completed
        if (editProfilePage.completedRequests >= editProfilePage.requests.length) {
            cleanupConnections()
            saving = false
            
            if (editProfilePage.failedRequests.length === editProfilePage.requests.length) {
                // All failed
                errorLabel.text = "All updates failed: " + editProfilePage.failedRequests.join(", ")
            } else {
                // Some failed
                errorLabel.text = "Some updates failed: " + editProfilePage.failedRequests.join(", ")
            }
        }
    }
    
    function cleanupConnections() {
        if (editProfilePage.successConnection) {
            SerchatAPI.profileUpdateSuccess.disconnect(editProfilePage.successConnection)
            editProfilePage.successConnection = null
        }
        if (editProfilePage.failureConnection) {
            SerchatAPI.profileUpdateFailed.disconnect(editProfilePage.failureConnection)
            editProfilePage.failureConnection = null
        }
    }
    
    function handleImageSelected(filePath) {
        errorLabel.text = ""
        
        // Buffer the image path for later upload
        if (imagePickerTarget === "avatar") {
            bufferedAvatarPath = filePath
        } else if (imagePickerTarget === "banner") {
            bufferedBannerPath = filePath
        }
    }
}
