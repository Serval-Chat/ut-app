import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MembersListView - Panel showing server members with search
 */
Rectangle {
    id: membersPanel
    
    property string serverId: ""
    property var members: []
    property bool loading: false
    property string searchQuery: ""
    property string currentUserId: ""
    
    signal memberClicked(string userId)
    signal close()
    
    color: Qt.darker(Theme.palette.normal.background, 1.08)
    width: units.gu(30)
    
    // Filter members based on search
    property var filteredMembers: {
        if (!searchQuery || searchQuery.trim() === "") {
            return members
        }
        var query = searchQuery.toLowerCase()
        return members.filter(function(member) {
            var displayName = (member.displayName || member.username || "").toLowerCase()
            var username = (member.username || "").toLowerCase()
            return displayName.indexOf(query) !== -1 || username.indexOf(query) !== -1
        })
    }
    
    // Group members by status
    property var onlineMembers: filteredMembers.filter(function(m) {
        var status = m.customStatus ? m.customStatus.status : "online"
        return status !== "offline" && status !== "invisible"
    })
    
    property var offlineMembers: filteredMembers.filter(function(m) {
        var status = m.customStatus ? m.customStatus.status : "online"
        return status === "offline" || status === "invisible"
    })
    
    Column {
        anchors.fill: parent
        
        // Header
        Rectangle {
            width: parent.width
            height: units.gu(6)
            color: membersPanel.color
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1.5)
                anchors.rightMargin: units.gu(1.5)
                spacing: units.gu(1)
                
                Label {
                    text: i18n.tr("Members")
                    font.bold: true
                    fontSize: "medium"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - closeButton.width - units.gu(2)
                }
                
                AbstractButton {
                    id: closeButton
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
            
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.dp(1)
                color: Qt.darker(membersPanel.color, 1.15)
            }
        }
        
        // Search box
        Rectangle {
            width: parent.width - units.gu(2)
            height: units.gu(4.5)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: units.gu(0.5)
            color: Qt.darker(membersPanel.color, 1.15)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                spacing: units.gu(0.5)
                
                Icon {
                    width: units.gu(2)
                    height: units.gu(2)
                    name: "search"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                TextField {
                    id: searchField
                    width: parent.width - units.gu(3)
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: i18n.tr("Search members")
                    onTextChanged: searchQuery = text
                }
            }
        }
        
        Item { width: 1; height: units.gu(1) }
        
        // Loading indicator
        Item {
            width: parent.width
            height: units.gu(10)
            visible: loading
            
            ActivityIndicator {
                anchors.centerIn: parent
                running: loading
            }
        }
        
        // Members list
        Flickable {
            width: parent.width
            height: parent.height - units.gu(12.5)
            contentHeight: membersColumn.height
            clip: true
            visible: !loading
            
            Column {
                id: membersColumn
                width: parent.width
                spacing: units.gu(0.5)
                
                // Online section
                Item {
                    width: parent.width
                    height: units.gu(3)
                    visible: onlineMembers.length > 0
                    
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1.5)
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n.tr("ONLINE — %1").arg(onlineMembers.length)
                        fontSize: "x-small"
                        font.bold: true
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
                
                Repeater {
                    model: onlineMembers
                    
                    Rectangle {
                        width: membersColumn.width
                        height: units.gu(5)
                        color: memberMouseArea.pressed ? Qt.darker(membersPanel.color, 1.2) : "transparent"
                        
                        property var member: modelData
                        property bool isCurrentUser: (modelData._id || modelData.id) === currentUserId
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: units.gu(1.5)
                            anchors.rightMargin: units.gu(1.5)
                            spacing: units.gu(1)
                            
                            Components.Avatar {
                                width: units.gu(4)
                                height: units.gu(4)
                                anchors.verticalCenter: parent.verticalCenter
                                name: member.displayName || member.username || ""
                                source: member.profilePicture ? SerchatAPI.apiBaseUrl + member.profilePicture : ""
                                showStatus: true
                                status: member.customStatus ? (member.customStatus.status || "online") : "online"
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - units.gu(6)
                                spacing: units.gu(0.2)
                                
                                Row {
                                    spacing: units.gu(0.5)
                                    
                                    Label {
                                        text: member.displayName || member.username || i18n.tr("Unknown")
                                        fontSize: "small"
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: isCurrentUser ? i18n.tr("(you)") : ""
                                        fontSize: "x-small"
                                        color: Theme.palette.normal.backgroundSecondaryText
                                        visible: isCurrentUser
                                    }
                                }
                                
                                Label {
                                    text: member.customStatus && member.customStatus.text ? 
                                          member.customStatus.text : ""
                                    fontSize: "x-small"
                                    color: Theme.palette.normal.backgroundSecondaryText
                                    elide: Text.ElideRight
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }
                        }
                        
                        MouseArea {
                            id: memberMouseArea
                            anchors.fill: parent
                            onClicked: memberClicked(modelData._id || modelData.id)
                        }
                    }
                }
                
                // Offline section
                Item {
                    width: parent.width
                    height: units.gu(3)
                    visible: offlineMembers.length > 0
                    
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1.5)
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n.tr("OFFLINE — %1").arg(offlineMembers.length)
                        fontSize: "x-small"
                        font.bold: true
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
                
                Repeater {
                    model: offlineMembers
                    
                    Rectangle {
                        width: membersColumn.width
                        height: units.gu(5)
                        color: offlineMouseArea.pressed ? Qt.darker(membersPanel.color, 1.2) : "transparent"
                        
                        property var member: modelData
                        property bool isCurrentUser: (modelData._id || modelData.id) === currentUserId
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: units.gu(1.5)
                            anchors.rightMargin: units.gu(1.5)
                            spacing: units.gu(1)
                            
                            Components.Avatar {
                                width: units.gu(4)
                                height: units.gu(4)
                                anchors.verticalCenter: parent.verticalCenter
                                name: member.displayName || member.username || ""
                                source: member.profilePicture ? SerchatAPI.apiBaseUrl + member.profilePicture : ""
                                showStatus: true
                                status: "offline"
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - units.gu(6)
                                spacing: units.gu(0.2)
                                
                                Row {
                                    spacing: units.gu(0.5)
                                    
                                    Label {
                                        text: member.displayName || member.username || i18n.tr("Unknown")
                                        fontSize: "small"
                                        font.bold: true
                                        elide: Text.ElideRight
                                        color: Theme.palette.normal.backgroundSecondaryText
                                    }
                                    
                                    Label {
                                        text: isCurrentUser ? i18n.tr("(you)") : ""
                                        fontSize: "x-small"
                                        color: Theme.palette.normal.backgroundSecondaryText
                                        visible: isCurrentUser
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: offlineMouseArea
                            anchors.fill: parent
                            onClicked: memberClicked(modelData._id || modelData.id)
                        }
                    }
                }
                
                // Empty state
                Item {
                    width: parent.width
                    height: units.gu(10)
                    visible: filteredMembers.length === 0 && !loading
                    
                    Label {
                        anchors.centerIn: parent
                        text: searchQuery ? i18n.tr("No members found") : i18n.tr("No members")
                        color: Theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
        }
    }
    
    // Fetch members when serverId changes
    onServerIdChanged: {
        if (serverId) {
            fetchMembers()
        }
    }
    
    function fetchMembers() {
        loading = true
        SerchatAPI.getServerMembers(serverId)
    }
    
    // Connection for real API
    Connections {
        target: SerchatAPI
        
        onServerMembersFetched: {
            if (serverId === membersPanel.serverId) {
                membersPanel.members = members
                loading = false
            }
        }
        
        onServerMembersFetchFailed: {
            if (serverId === membersPanel.serverId) {
                loading = false
                console.error("[MembersListView] Failed to fetch members:", error)
            }
        }
    }
}
