import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: serverSettingsPage
    
    property string serverId: ""
    property string serverName: ""
    property var serverDetails: ({})
    property bool loading: true
    
    header: PageHeader {
        id: header
        title: serverName || i18n.tr("Server Settings")
        
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
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
            
            // Server Overview Section
            ListItem {
                height: overviewSection.height + divider.height
                
                ListItemLayout {
                    id: overviewSection
                    title.text: i18n.tr("Overview")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: nameLayout.height + divider.height
                onClicked: {
                    // TODO: Edit server name
                }
                
                ListItemLayout {
                    id: nameLayout
                    title.text: i18n.tr("Server Name")
                    subtitle.text: serverDetails.name || serverName
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: iconLayout.height + divider.height
                onClicked: {
                    // TODO: Change server icon
                }
                
                ListItemLayout {
                    id: iconLayout
                    title.text: i18n.tr("Server Icon")
                    subtitle.text: serverDetails.icon ? i18n.tr("Custom icon") : i18n.tr("No icon set")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Channels Section
            ListItem {
                height: channelsSection.height + divider.height
                
                ListItemLayout {
                    id: channelsSection
                    title.text: i18n.tr("Channels")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: manageChannelsLayout.height + divider.height
                onClicked: {
                    // TODO: Manage channels
                }
                
                ListItemLayout {
                    id: manageChannelsLayout
                    title.text: i18n.tr("Manage Channels")
                    subtitle.text: i18n.tr("Create, edit, and delete channels")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Roles Section
            ListItem {
                height: rolesSection.height + divider.height
                
                ListItemLayout {
                    id: rolesSection
                    title.text: i18n.tr("Roles")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: manageRolesLayout.height + divider.height
                onClicked: {
                    // TODO: Manage roles
                }
                
                ListItemLayout {
                    id: manageRolesLayout
                    title.text: i18n.tr("Manage Roles")
                    subtitle.text: i18n.tr("Create and configure roles")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Members Section
            ListItem {
                height: membersSection.height + divider.height
                
                ListItemLayout {
                    id: membersSection
                    title.text: i18n.tr("Members")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: viewMembersLayout.height + divider.height
                onClicked: {
                    // TODO: View members
                }
                
                ListItemLayout {
                    id: viewMembersLayout
                    title.text: i18n.tr("View Members")
                    subtitle.text: (serverDetails.memberCount || 0) + i18n.tr(" members")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            ListItem {
                height: bansLayout.height + divider.height
                onClicked: {
                    // TODO: View bans
                }
                
                ListItemLayout {
                    id: bansLayout
                    title.text: i18n.tr("Bans")
                    subtitle.text: i18n.tr("View and manage banned users")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Invites Section
            ListItem {
                height: invitesSection.height + divider.height
                
                ListItemLayout {
                    id: invitesSection
                    title.text: i18n.tr("Invites")
                    title.font.bold: true
                }
            }
            
            ListItem {
                height: manageInvitesLayout.height + divider.height
                onClicked: {
                    // TODO: Manage invites
                }
                
                ListItemLayout {
                    id: manageInvitesLayout
                    title.text: i18n.tr("Manage Invites")
                    subtitle.text: i18n.tr("Create and view invite links")
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                    }
                }
            }
            
            // Danger Zone
            ListItem {
                height: dangerSection.height + divider.height
                
                ListItemLayout {
                    id: dangerSection
                    title.text: i18n.tr("Danger Zone")
                    title.font.bold: true
                    title.color: LomiriColors.red
                }
            }
            
            ListItem {
                height: leaveLayout.height + divider.height
                onClicked: {
                    // TODO: Leave server confirmation
                }
                
                ListItemLayout {
                    id: leaveLayout
                    title.text: i18n.tr("Leave Server")
                    title.color: LomiriColors.red
                    
                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2)
                        color: LomiriColors.red
                    }
                }
            }
        }
    }
    
    // Loading overlay
    Components.LoadingOverlay {
        visible: loading
    }
    
    Connections {
        target: SerchatAPI
        
        onServerDetailsFetched: {
            if (server._id === serverId || server.id === serverId) {
                serverDetails = server
                serverName = server.name
                loading = false
            }
        }
        
        onServerDetailsFetchFailed: {
            loading = false
            console.log("Failed to load server details:", error)
        }
    }
    
    Component.onCompleted: {
        if (serverId) {
            SerchatAPI.getServerDetails(serverId)
        } else {
            loading = false
        }
    }
}
