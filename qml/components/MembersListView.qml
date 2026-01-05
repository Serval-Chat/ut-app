import QtQuick 2.7
import Lomiri.Components 1.3

import SerchatAPI 1.0
import "." as Components

/*
 * MembersListView - Panel showing server members with search
 * 
 * Online status is determined by SerchatAPI.isUserOnline() which tracks
 * presence via socket events (presence_state, user_online, user_offline)
 * 
 * Members are grouped by roles (roles with separateFromOtherRoles=true)
 * and then by online/offline status.
 * 
 * Data is managed via C++ models (SerchatAPI.membersModel, SerchatAPI.rolesModel)
 * for better performance and proper scroll behavior.
 */
Rectangle {
    id: membersPanel
    
    property string serverId: ""
    property bool loading: false
    property string searchQuery: ""
    property string currentUserId: ""
    
    // Track when online users change to trigger re-grouping
    property int onlineUsersVersion: 0
    
    // Track model updates to trigger re-grouping
    property int membersVersion: 0
    property int rolesVersion: 0
    
    // Track which server's data is currently loaded in the model
    property string loadedServerId: ""
    
    signal memberClicked(string userId)
    signal close()
    
    color: Qt.darker(Theme.palette.normal.background, 1.08)
    width: units.gu(30)
    
    // Get members array from C++ model (triggered by membersVersion changes)
    property var members: {
        var v = membersVersion  // Force dependency on version
        return SerchatAPI.membersModel.toList()
    }
    
    // Get roles array from C++ model (triggered by rolesVersion changes)
    property var roles: {
        var v = rolesVersion  // Force dependency on version
        return SerchatAPI.rolesModel.toList()
    }
    
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
    
    // Helper function to check if a member is online using presence tracking
    function isMemberOnline(member) {
        var user = member.user || {}
        var username = user.username || ""
        return SerchatAPI.isUserOnline(username)
    }
    
    // Build a map of roleId -> role for quick lookup
    property var roleMap: {
        var map = {}
        for (var i = 0; i < roles.length; i++) {
            var role = roles[i]
            map[role._id] = role
        }
        return map
    }
    
    // Get sorted separable roles (those with separateFromOtherRoles=true)
    // Sorted by position descending (highest position = shown first)
    property var separableRoles: {
        var separable = roles.filter(function(r) {
            return r.separateFromOtherRoles === true
        })
        separable.sort(function(a, b) {
            return (b.position || 0) - (a.position || 0)
        })
        return separable
    }
    
    // Get highest separable role for a member
    function getHighestSeparableRole(member) {
        var memberRoles = member.roles || []
        var highestRole = null
        var highestPosition = -1
        
        for (var i = 0; i < memberRoles.length; i++) {
            var roleId = memberRoles[i]
            var role = roleMap[roleId]
            if (role && role.separateFromOtherRoles === true) {
                var pos = role.position || 0
                if (pos > highestPosition) {
                    highestPosition = pos
                    highestRole = role
                }
            }
        }
        return highestRole
    }
    
    // Generate grouped members structure
    // Returns: [{ role: roleObject|null, members: [...], isOnline: bool }]
    property var groupedMembers: {
        var version = onlineUsersVersion  // Force dependency
        var groups = []
        var processedMemberIds = {}
        
        // First, group online members by their highest separable role
        for (var i = 0; i < separableRoles.length; i++) {
            var role = separableRoles[i]
            var roleMembers = []
            
            for (var j = 0; j < filteredMembers.length; j++) {
                var member = filteredMembers[j]
                if (processedMemberIds[member._id]) continue
                if (!isMemberOnline(member)) continue
                
                var highestRole = getHighestSeparableRole(member)
                if (highestRole && highestRole._id === role._id) {
                    roleMembers.push(member)
                    processedMemberIds[member._id] = true
                }
            }
            
            if (roleMembers.length > 0) {
                groups.push({
                    role: role,
                    members: roleMembers,
                    isOnline: true
                })
            }
        }
        
        // Then, remaining online members (without separable roles)
        var onlineWithoutRole = []
        for (var k = 0; k < filteredMembers.length; k++) {
            var onlineMember = filteredMembers[k]
            if (processedMemberIds[onlineMember._id]) continue
            if (isMemberOnline(onlineMember)) {
                onlineWithoutRole.push(onlineMember)
                processedMemberIds[onlineMember._id] = true
            }
        }
        if (onlineWithoutRole.length > 0) {
            groups.push({
                role: null,
                members: onlineWithoutRole,
                isOnline: true
            })
        }
        
        // Finally, offline members
        var offlineMembers = []
        for (var l = 0; l < filteredMembers.length; l++) {
            var offMember = filteredMembers[l]
            if (!processedMemberIds[offMember._id]) {
                offlineMembers.push(offMember)
            }
        }
        if (offlineMembers.length > 0) {
            groups.push({
                role: null,
                members: offlineMembers,
                isOnline: false
            })
        }
        
        return groups
    }
    
    // Helper to get group header text
    function getGroupHeader(group) {
        if (group.role) {
            return group.role.name.toUpperCase() + " — " + group.members.length
        } else if (group.isOnline) {
            return i18n.tr("ONLINE — %1").arg(group.members.length)
        } else {
            return i18n.tr("OFFLINE — %1").arg(group.members.length)
        }
    }
    
    // Track C++ model changes
    Connections {
        target: SerchatAPI.membersModel
        onCountChanged: membersPanel.membersVersion++
    }
    
    Connections {
        target: SerchatAPI.rolesModel
        onCountChanged: membersPanel.rolesVersion++
    }
    
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
                
                // Dynamic group sections based on roles and online/offline status
                Repeater {
                    model: groupedMembers
                    
                    Column {
                        width: membersColumn.width
                        spacing: units.gu(0.5)
                        
                        // Group header
                        Item {
                            width: parent.width
                            height: units.gu(3)
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: units.gu(1.5)
                                anchors.verticalCenter: parent.verticalCenter
                                text: getGroupHeader(modelData)
                                fontSize: "x-small"
                                font.bold: true
                                color: modelData.role ? modelData.role.color || Theme.palette.normal.backgroundSecondaryText : Theme.palette.normal.backgroundSecondaryText
                            }
                        }
                        
                        // Members in this group
                        Repeater {
                            model: modelData.members
                            
                            Components.MemberListItem {
                                width: membersColumn.width
                                member: modelData
                                currentUserId: membersPanel.currentUserId
                                isOffline: !isMemberOnline(modelData)
                                panelColor: membersPanel.color
                                
                                onClicked: memberClicked(memberId)
                            }
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
        if (serverId && visible) {
            fetchMembers()
            fetchRoles()
        }
    }
    
    // Also fetch when the panel becomes visible if we have stale data
    onVisibleChanged: {
        // Fetch if visible and either:
        // 1. No data loaded yet (model empty), or
        // 2. Data is from a different server than we're currently viewing
        var needsFetch = SerchatAPI.membersModel.count === 0 || loadedServerId !== serverId
        if (visible && serverId && needsFetch && !loading) {
            fetchMembers()
            fetchRoles()
        }
    }
    
    function fetchMembers() {
        if (!serverId) return
        loading = true
        SerchatAPI.getServerMembers(serverId)
    }
    
    function fetchRoles() {
        if (!serverId) return
        SerchatAPI.getServerRoles(serverId)
    }
    
    // Connection for API signals
    Connections {
        target: SerchatAPI
        
        onServerMembersFetched: {
            if (serverId === membersPanel.serverId) {
                // Model is populated by C++, track which server's data we have
                membersPanel.loadedServerId = serverId
                loading = false
            }
        }
        
        onServerMembersFetchFailed: {
            if (serverId === membersPanel.serverId) {
                loading = false
                console.error("[MembersListView] Failed to fetch members:", error)
            }
        }
        
        onServerRolesFetched: {
            if (serverId === membersPanel.serverId) {
                // Model is populated by C++, just trigger re-render
                membersPanel.rolesVersion++
            }
        }
        
        // Update online status display when presence changes
        onOnlineUsersChanged: {
            membersPanel.onlineUsersVersion++
        }
        
        // Refresh members list when a member joins or leaves the server
        onServerMemberJoined: {
            if (serverId === membersPanel.serverId && visible) {
                // Refresh the members list to include the new member
                fetchMembers()
            }
        }
        
        onServerMemberLeft: {
            if (serverId === membersPanel.serverId && visible) {
                // Refresh the members list to remove the departed member
                fetchMembers()
            }
        }
    }
}