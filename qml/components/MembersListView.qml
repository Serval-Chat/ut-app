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
            // API returns: { user: { displayName, username, ... } }
            var user = member.user || {}
            var displayName = (user.displayName || user.username || "").toLowerCase()
            var username = (user.username || "").toLowerCase()
            return displayName.indexOf(query) !== -1 || username.indexOf(query) !== -1
        })
    }
    
    // Group members by status
    // API returns: { user: { customStatus: { status: "online|offline|..." } } }
    property var onlineMembers: filteredMembers.filter(function(m) {
        var user = m.user || {}
        var customStatus = user.customStatus || {}
        var status = customStatus.status || "offline"  // Default to offline if no status
        return status !== "offline" && status !== "invisible"
    })
    
    property var offlineMembers: filteredMembers.filter(function(m) {
        var user = m.user || {}
        var customStatus = user.customStatus || {}
        var status = customStatus.status || "offline"  // Default to offline if no status
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
                
                Components.IconButton {
                    id: closeButton
                    iconName: "close"
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
        Components.SearchBox {
            width: parent.width - units.gu(2)
            anchors.horizontalCenter: parent.horizontalCenter
            placeholderText: i18n.tr("Search members")
            onTextChanged: searchQuery = text
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
                    
                    Components.MemberListItem {
                        width: membersColumn.width
                        member: modelData
                        currentUserId: membersPanel.currentUserId
                        isOffline: false
                        panelColor: membersPanel.color
                        
                        onClicked: memberClicked(memberId)
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
                    
                    Components.MemberListItem {
                        width: membersColumn.width
                        member: modelData
                        currentUserId: membersPanel.currentUserId
                        isOffline: true
                        panelColor: membersPanel.color
                        
                        onClicked: memberClicked(memberId)
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
        if (serverId && visible) {
            fetchMembers()
        }
    }
    
    // Also fetch when the panel becomes visible (first open)
    onVisibleChanged: {
        if (visible && serverId && members.length === 0 && !loading) {
            fetchMembers()
        }
    }
    
    function fetchMembers() {
        if (!serverId) return
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
