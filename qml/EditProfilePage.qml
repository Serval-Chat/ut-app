import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: editProfilePage
    
    property var userProfile: ({})
    property bool saving: false
    
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
                            // TODO: Open image picker
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
        var name = userProfile.username || "user"
        var colors = ["#7289da", "#43b581", "#faa61a", "#f04747", "#9b59b6"]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        return colors[Math.abs(hash) % colors.length]
    }
    
    function saveProfile() {
        saving = true
        errorLabel.text = ""
        
        // TODO: Implement actual profile update API calls
        console.log("Saving profile:", {
            displayName: displayNameField.text,
            pronouns: pronounsField.text,
            bio: bioField.text
        })
        
        // Simulate for now
        Qt.callLater(function() {
            saving = false
            errorLabel.text = i18n.tr("Profile update not yet implemented")
        })
    }
}
