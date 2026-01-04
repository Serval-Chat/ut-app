import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: settingsPage
    
    header: PageHeader {
        id: header
        title: i18n.tr("Settings")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }
    
    property var userProfile: ({})
    property bool loading: true
    
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
            
            // User Profile Section
            Rectangle {
                width: parent.width
                height: profileRow.height + units.gu(3)
                radius: units.gu(1)
                color: Theme.palette.normal.base
                
                Row {
                    id: profileRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(1.5)
                    }
                    spacing: units.gu(2)
                    
                    Components.Avatar {
                        id: profileAvatar
                        width: units.gu(8)
                        height: units.gu(8)
                        name: userProfile.displayName || userProfile.username || ""
                        source: userProfile.profilePicture ? 
                                (SerchatAPI.apiBaseUrl + userProfile.profilePicture) : ""
                        showStatus: true
                        status: "online"
                    }
                    
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.5)
                        width: parent.width - profileAvatar.width - editProfileButton.width - units.gu(4)
                        
                        Label {
                            text: userProfile.displayName || userProfile.username || i18n.tr("Loading...")
                            fontSize: "large"
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        Label {
                            text: "@" + (userProfile.username || "")
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            visible: userProfile.username !== undefined
                        }
                        
                        Label {
                            text: userProfile.bio || ""
                            fontSize: "small"
                            color: Theme.palette.normal.backgroundSecondaryText
                            wrapMode: Text.Wrap
                            width: parent.width
                            visible: !!userProfile.bio
                        }
                    }
                    
                    Button {
                        id: editProfileButton
                        text: i18n.tr("Edit")
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("EditProfilePage.qml"), {
                                userProfile: userProfile
                            })
                        }
                    }
                }
            }
            
            // Account Section
            ListItem {
                height: accountSection.height + divider.height
                
                ListItemLayout {
                    id: accountSection
                    title.text: i18n.tr("Account")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: layout1.height + divider.height
                onClicked: {
                    // TODO: Change username
                }
                
                ListItemLayout {
                    id: layout1
                    title.text: i18n.tr("Username")
                    subtitle.text: "@" + (userProfile.username || "")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: layout2.height + divider.height
                onClicked: {
                    // TODO: Change email
                }
                
                ListItemLayout {
                    id: layout2
                    title.text: i18n.tr("Email")
                    subtitle.text: userProfile.login || i18n.tr("Not set")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: layout3.height + divider.height
                onClicked: {
                    // TODO: Change password
                }
                
                ListItemLayout {
                    id: layout3
                    title.text: i18n.tr("Change Password")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Appearance Section
            ListItem {
                height: appearanceSection.height + divider.height
                
                ListItemLayout {
                    id: appearanceSection
                    title.text: i18n.tr("Appearance")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: themeLayout.height + divider.height
                
                ListItemLayout {
                    id: themeLayout
                    title.text: i18n.tr("Theme")
                    subtitle.text: i18n.tr("System default")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Notifications Section
            ListItem {
                height: notifSection.height + divider.height
                
                ListItemLayout {
                    id: notifSection
                    title.text: i18n.tr("Notifications")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: notifLayout.height + divider.height
                
                ListItemLayout {
                    id: notifLayout
                    title.text: i18n.tr("Enable Notifications")
                    
                    Switch {
                        id: notifSwitch
                        checked: true
                        SlotsLayout.position: SlotsLayout.Trailing
                    }
                }
            }
            
            ListItem {
                height: mentionLayout.height + divider.height
                
                ListItemLayout {
                    id: mentionLayout
                    title.text: i18n.tr("Mention Notifications Only")
                    subtitle.text: i18n.tr("Only notify for @mentions")
                    
                    Switch {
                        id: mentionSwitch
                        checked: false
                        SlotsLayout.position: SlotsLayout.Trailing
                    }
                }
            }
            
            // Advanced Section
            ListItem {
                height: advancedSection.height + divider.height
                
                ListItemLayout {
                    id: advancedSection
                    title.text: i18n.tr("Advanced")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: apiLayout.height + divider.height
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("ApiSettingsPage.qml"))
                }
                
                ListItemLayout {
                    id: apiLayout
                    title.text: i18n.tr("API Settings")
                    subtitle.text: SerchatAPI.apiBaseUrl
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: debugLayout.height + divider.height
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("DebugPage.qml"))
                }
                
                ListItemLayout {
                    id: debugLayout
                    title.text: i18n.tr("Debug")
                    subtitle.text: i18n.tr("Developer tools")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: cacheLayout.height + divider.height
                onClicked: {
                    SerchatAPI.clearCache()
                }
                
                ListItemLayout {
                    id: cacheLayout
                    title.text: i18n.tr("Clear Cache")
                    subtitle.text: i18n.tr("Clear locally stored data")
                    
                    Icon {
                        name: "reload"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // About Section
            ListItem {
                height: aboutSection.height + divider.height
                
                ListItemLayout {
                    id: aboutSection
                    title.text: i18n.tr("About")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: versionLayout.height + divider.height
                
                ListItemLayout {
                    id: versionLayout
                    title.text: i18n.tr("Version")
                    subtitle.text: Qt.application.version
                }
            }
            
            // Logout button
            Item {
                width: parent.width
                height: units.gu(8)
                
                Button {
                    anchors.centerIn: parent
                    width: parent.width - units.gu(4)
                    text: i18n.tr("Log Out")
                    color: LomiriColors.red
                    onClicked: {
                        SerchatAPI.logout()
                        pageStack.clear()
                        pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
                    }
                }
            }
        }
    }
    
    // Loading indicator
    ActivityIndicator {
        anchors.centerIn: parent
        running: loading
        visible: loading
    }
    
    Connections {
        target: SerchatAPI
        
        onMyProfileFetched: {
            userProfile = profile
            loading = false
        }
        
        onMyProfileFetchFailed: {
            loading = false
            console.log("Failed to load profile:", error)
        }
    }
    
    Component.onCompleted: {
        SerchatAPI.getMyProfile()
    }
}
