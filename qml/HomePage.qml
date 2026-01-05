import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: homePage
    
    // Hide default header - we use custom headers in views
    header: Item { height: 0 }
    
    // State management
    property string currentServerId: ""
    property string currentServerName: ""
    property string currentServerOwnerId: ""
    property string currentChannelId: ""
    property string currentChannelName: ""
    property string currentChannelType: "text"
    property var currentChannelPermissions: ({})  // Channel-specific permission overrides
    property string currentUserId: ""
    property string currentUserName: ""
    property string currentUserAvatar: ""
    
    // DM state
    property string currentDMRecipientId: ""
    property string currentDMRecipientName: ""
    property string currentDMRecipientAvatar: ""
    
    // Computed permission for current channel
    // For now, simple check: owner always can send, channels without explicit deny allow sending
    readonly property bool canSendInCurrentChannel: {
        // DMs always allow sending
        if (currentDMRecipientId !== "") return true
        // No server/channel selected
        if (currentServerId === "" || currentChannelId === "") return false
        // Server owner can always send
        if (currentUserId === currentServerOwnerId) return true
        // For now, allow sending in all channels (proper permission checking needs member roles)
        // The server will reject unauthorized messages anyway
        return true
    }
    
    // View mode for mobile: "channels", "messages"
    property string mobileViewMode: "channels"
    
    // Data stores
    property var servers: []
    // Channels and categories are now managed by SerchatAPI.channelListModel
    // Messages are now managed by SerchatAPI.messageModel (C++ QAbstractListModel)
    property var unreadCounts: ({})
    
    // DM data stores
    property var dmConversations: []
    property var dmUnreadCounts: ({})
    
    // Loading states
    property bool loadingServers: false
    property bool loadingChannels: false
    property bool loadingMessages: false
    // hasMoreMessages is now managed by SerchatAPI.messageModel.hasMoreMessages
    
    // Responsive layout threshold
    readonly property bool isWideScreen: width >= units.gu(150)
    readonly property bool isSmallScreen: !isWideScreen
    
    // Sidebar width calculations for mobile overlay mode
    readonly property real serverListWidth: units.gu(7)
    readonly property real channelListWidth: units.gu(26)
    
    // Animation duration for smooth transitions
    readonly property int animationDuration: 250
    
    // Calculate sidebar positions for small screen sliding panel
    readonly property real totalSidebarWidth: serverListWidth + channelListWidth
    readonly property real sidebarX: {
        if (!isSmallScreen) return 0  // Fixed position on wide/medium screens
        switch (mobileViewMode) {
            case "channels": return 0  // Show both sidebars
            case "messages": return -sidebarContainer.width  // Hide sidebars off-screen
            default: return 0
        }
    }
    
    // Calculate main content position for small screens - slides with sidebar
    readonly property real mainContentX: {
        if (!isSmallScreen) return serverListWidth + channelListWidth
        switch (mobileViewMode) {
            case "channels": return sidebarContainer.width  // Shows after sidebar
            case "messages": return 0  // Full screen
            default: return 0
        }
    }
    
    // Calculate visible sidebar width for drop shadow positioning
    readonly property real visibleSidebarWidth: {
        if (!isSmallScreen) return totalSidebarWidth
        switch (mobileViewMode) {
            case "channels": return parent.width * 0.85
            case "messages": return 0
            default: return parent.width * 0.85
        }
    }
    
    // Shadow position for smooth animation
    property real shadowLeftMargin: visibleSidebarWidth
    
    Behavior on shadowLeftMargin {
        NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
    }
    
    // Main content area (message view + placeholder) - rendered first so sidebars appear on top
    Item {
        id: mainContentArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        
        // On small screens, this slides with the sidebar
        // On wide/medium screens, it's fixed after sidebars
        x: mainContentX
        width: parent.width - (isSmallScreen ? 0 : (serverListWidth + channelListWidth))
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        Behavior on width {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        // Message view (main content area)
        Components.MessageView {
            id: messageView
            anchors.fill: parent
            visible: currentChannelId !== "" || currentDMRecipientId !== ""
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            // Server channel properties
            serverId: currentServerId
            channelId: currentChannelId
            channelName: currentChannelName
            channelType: currentChannelType
            
            // DM properties
            dmRecipientId: currentDMRecipientId
            dmRecipientName: currentDMRecipientName
            dmRecipientAvatar: currentDMRecipientAvatar
            
            // Messages are now handled by C++ model (SerchatAPI.messageModel)
            loading: loadingMessages
            currentUserId: homePage.currentUserId
            showBackButton: isSmallScreen && mobileViewMode === "messages"
            canSendMessages: homePage.canSendInCurrentChannel
            
            onBackClicked: {
                mobileViewMode = "channels"
            }
            
            onSendMessage: {
                // Check if we're in DM mode or channel mode
                if (currentDMRecipientId !== "") {
                    sendDMMessageToUser(text, replyToId)
                } else {
                    sendMessageToChannel(text, replyToId)
                }
            }
            
            onLoadMoreMessages: {
                // Check if we're in DM mode or channel mode
                if (currentDMRecipientId !== "") {
                    loadOlderDMMessages()
                } else {
                    loadOlderMessages()
                }
            }
            
            onUserProfileClicked: {
                pageStack.push(Qt.resolvedUrl("ProfilePage.qml"), {
                    userId: userId
                })
            }
            
            onViewFullProfile: {
                pageStack.push(Qt.resolvedUrl("ProfilePage.qml"), {
                    userId: userId
                })
            }
            
            onOpenDMWithUser: {
                // Clear unread divider for channel when leaving
                if (currentServerId && currentChannelId) {
                    SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
                    SerchatAPI.leaveChannel(currentServerId, currentChannelId)
                }

                // Set viewing state BEFORE setting currentDMRecipientId
                SerchatAPI.viewingServerId = ""
                SerchatAPI.viewingChannelId = ""
                SerchatAPI.viewingDMRecipientId = recipientId

                // Switch to DM mode with the selected user
                currentDMRecipientId = recipientId
                currentDMRecipientName = recipientName
                currentDMRecipientAvatar = recipientAvatar

                // Clear server/channel state
                currentChannelId = ""
                currentChannelName = ""
                currentServerId = ""
                currentServerName = ""

                loadDMMessages(recipientId)

                if (isSmallScreen) {
                    mobileViewMode = "messages"
                }
            }
            
            onSendFriendRequest: {
                // Send friend request via API (when implemented)
                console.log("Sending friend request to:", username, "userId:", userId)
                // TODO: Call SerchatAPI.sendFriendRequest(username) when implemented
            }
        }
        
        // Empty state placeholder (always visible when no channel/DM selected)
        Rectangle {
            id: placeholderView
            anchors.fill: parent
            visible: currentChannelId === "" && currentDMRecipientId === ""
            opacity: visible ? 1 : 0
            color: Theme.palette.normal.background
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            // Header with back button for small screens
            Rectangle {
                id: placeholderHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: units.gu(6)
                color: Qt.darker(parent.color, 1.02)
                visible: isSmallScreen && mobileViewMode === "messages"
                
                AbstractButton {
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1.5)
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(4)
                    height: parent.height
                    
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(2.5)
                        height: units.gu(2.5)
                        name: "back"
                        color: Theme.palette.normal.baseText
                    }
                    
                    onClicked: mobileViewMode = "channels"
                }
                
                Label {
                    anchors.centerIn: parent
                    text: currentServerId === "" ? i18n.tr("Direct Messages") : currentServerName
                    fontSize: "medium"
                    color: Theme.palette.normal.baseText
                }
            }
            
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: placeholderHeader.visible ? placeholderHeader.height / 2 : 0
                spacing: units.gu(2)
                width: Math.min(parent.width - units.gu(4), units.gu(40))
                
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(10)
                    height: units.gu(10)
                    name: currentServerId === "" ? "message" : "edit"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentServerId === "" ? 
                          i18n.tr("Select a conversation") : 
                          i18n.tr("Select a channel")
                    fontSize: "large"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentServerId === "" ?
                          i18n.tr("Choose a conversation from the list or start a new one") :
                          i18n.tr("Pick a channel from the list to start chatting")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    width: parent.width
                }
            }
        }
    }
    
    // Semi-transparent overlay for dimming content when sidebar is open on small screens
    Rectangle {
        id: sidebarOverlay
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Position overlay at the content area's x position
        x: mainContentX
        width: parent.width
        color: "#000000"
        opacity: {
            if (!isSmallScreen) return 0
            if (mobileViewMode === "messages") return 0
            // Show overlay when sidebar is visible
            return 0.5
        }
        visible: opacity > 0
        z: 5
        
        Behavior on opacity {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: parent.visible && (currentChannelId !== "" || currentDMRecipientId !== "")
            onClicked: {
                mobileViewMode = "messages"
            }
        }
    }
    
    // Sliding sidebar container
    Item {
        id: sidebarContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: isSmallScreen && mobileViewMode === "channels" ? parent.width * 0.85 : totalSidebarWidth
        x: sidebarX
        z: 10
        
        Behavior on x {
            NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
        }
        
        // Drop shadow for depth on small screens
        Row {
            anchors.left: parent.left
            anchors.leftMargin: shadowLeftMargin
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            visible: isSmallScreen && mobileViewMode !== "messages"
            
            Repeater {
                model: 8
                Rectangle {
                    width: units.gu(0.25)
                    height: parent.height
                    color: "#000000"
                    opacity: (8 - index) * 0.02
                }
            }
        }
        
        // Server sidebar
        Components.ServerListView {
            id: serverList
            anchors.left: parent.left
            height: parent.height
            width: serverListWidth
            // Always visible on wide screens, or on small screens when sidebar is showing
            visible: isWideScreen || (isSmallScreen && mobileViewMode !== "messages")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            servers: homePage.servers
            selectedServerId: currentServerId
            
            onServerSelected: {
                currentServerId = serverId
                currentServerName = serverName
                currentServerOwnerId = ownerId
                currentChannelId = ""
                currentChannelName = ""
                loadChannels(serverId)
                
                // Save state
                SerchatAPI.lastServerId = serverId
                SerchatAPI.lastChannelId = ""
                SerchatAPI.lastDMRecipientId = ""
                
                mobileViewMode = "channels"
            }
            
            onHomeClicked: {
                // Clear unread divider for channel when leaving
                if (currentServerId && currentChannelId) {
                    SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
                    SerchatAPI.leaveChannel(currentServerId, currentChannelId)
                }

                currentServerId = ""
                currentServerName = ""
                currentServerOwnerId = ""
                currentChannelId = ""
                currentDMRecipientId = ""
                currentDMRecipientName = ""
                currentDMRecipientAvatar = ""
                SerchatAPI.channelListModel.clear()
                SerchatAPI.messageModel.clear()

                // Clear viewing state when navigating away
                SerchatAPI.viewingServerId = ""
                SerchatAPI.viewingChannelId = ""
                SerchatAPI.viewingDMRecipientId = ""

                // Save state - clear all last IDs when going home
                SerchatAPI.lastServerId = ""
                SerchatAPI.lastChannelId = ""
                SerchatAPI.lastDMRecipientId = ""
                mobileViewMode = "channels"

                // Load DM conversations (friends list)
                loadDMConversations()
            }
            
            onAddServerClicked: {
                pageStack.push(Qt.resolvedUrl("JoinServerPage.qml"))
            }
            
            onSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
        }
        
        // DM list (visible when Home is selected instead of a server)
        Components.DMListView {
            id: dmListView
            anchors.left: serverList.right
            height: parent.height
            width: isSmallScreen && mobileViewMode === "channels" && currentServerId === "" ? parent.width - serverList.width : channelListWidth
            // Visible when no server selected (Home mode), but only in channels mode on small screens
            visible: currentServerId === "" && (!isSmallScreen || mobileViewMode === "channels")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            conversations: homePage.dmConversations
            unreadCounts: homePage.dmUnreadCounts
            selectedConversationId: currentDMRecipientId
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            
            onConversationSelected: {
                // Clear unread divider for old channel when leaving
                if (currentServerId && currentChannelId) {
                    SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
                    SerchatAPI.leaveChannel(currentServerId, currentChannelId)
                }

                // Set viewing state BEFORE setting currentDMRecipientId
                SerchatAPI.viewingServerId = ""
                SerchatAPI.viewingChannelId = ""
                SerchatAPI.viewingDMRecipientId = recipientId

                // Clear channel state when switching to DM
                currentChannelId = ""
                currentChannelName = ""
                currentChannelType = "text"

                // Set DM state
                currentDMRecipientId = recipientId
                currentDMRecipientName = recipientName
                currentDMRecipientAvatar = recipientAvatar
                loadDMMessages(recipientId)

                // Save state
                SerchatAPI.lastDMRecipientId = recipientId
                SerchatAPI.lastServerId = ""
                SerchatAPI.lastChannelId = ""

                mobileViewMode = "messages"
            }
            
            onBackClicked: {
                mobileViewMode = "channels"
            }
            
            onCreateDMClicked: {
                createDMDialog.open()
            }
        }
        
        // Channel sidebar (visible when server selected)
        Components.ChannelListView {
            id: channelList
            anchors.left: serverList.right
            height: parent.height
            width: isSmallScreen && mobileViewMode === "channels" ? parent.width - serverList.width : channelListWidth
            // Visible when a server is selected, but only in channels mode on small screens
            visible: currentServerId !== "" && (!isSmallScreen || mobileViewMode === "channels")
            opacity: visible ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation { duration: animationDuration; easing.type: Easing.OutCubic }
            }
            
            serverId: currentServerId
            serverName: currentServerName
            selectedChannelId: currentChannelId
            // Channels and categories now come from SerchatAPI.channelListModel
            currentUserName: homePage.currentUserName
            currentUserAvatar: homePage.currentUserAvatar
            
            onChannelSelected: {
                // Clear unread divider for old channel when leaving
                if (currentServerId && currentChannelId) {
                    SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
                    SerchatAPI.leaveChannel(currentServerId, currentChannelId)
                }

                // Clear DM state when switching to channel
                currentDMRecipientId = ""
                currentDMRecipientName = ""
                currentDMRecipientAvatar = ""

                // Set viewing state BEFORE updating channel
                SerchatAPI.viewingDMRecipientId = ""
                SerchatAPI.viewingServerId = currentServerId
                SerchatAPI.viewingChannelId = channelId

                currentChannelId = channelId
                currentChannelName = channelName
                currentChannelType = channelType
                loadMessages(currentServerId, channelId)

                // Save state
                SerchatAPI.lastChannelId = channelId
                mobileViewMode = "messages"
            }
            
            onBackClicked: {
                mobileViewMode = "channels"
            }
            
            onServerSettingsClicked: {
                pageStack.push(Qt.resolvedUrl("ServerSettingsPage.qml"), {
                    serverId: currentServerId,
                    serverName: currentServerName
                })
            }
        }
    }
    
    // Edge swipe gesture handler for revealing sidebar on small screens
    MouseArea {
        id: edgeSwipeArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: units.gu(2)
        visible: isSmallScreen && mobileViewMode === "messages"
        z: 15
        
        property real startX: 0
        property bool dragging: false
        
        onPressed: {
            startX = mouse.x
            dragging = true
        }
        
        onPositionChanged: {
            if (dragging && mouse.x - startX > units.gu(4)) {
                mobileViewMode = "channels"
                dragging = false
            }
        }
        
        onReleased: {
            dragging = false
        }
    }
    
    // Loading overlay
    Components.LoadingOverlay {
        z: 100
        visible: loadingServers && servers.length === 0
    }
    
    // ========================================================================
    // API Connections
    // ========================================================================
    
    Connections {
        target: SerchatAPI
        
        // Profile
        onMyProfileFetched: {
            currentUserId = profile.id || ""
            currentUserName = profile.displayName || profile.username || ""
            
            // Also set in C++ API for filtering own messages from unread counts
            SerchatAPI.currentUserId = profile.id || ""

            // Set avatar URL - profilePicture contains the full path
            if (profile.profilePicture) {
                currentUserAvatar = SerchatAPI.apiBaseUrl + profile.profilePicture
            }

            // Cache own profile in C++ cache (MessageModel uses this automatically)
            if (SerchatAPI.userProfileCache) {
                SerchatAPI.userProfileCache.updateProfile(profile.id, profile)
            }
        }
        
        onMyProfileFetchFailed: {
            console.log("Failed to fetch profile:", error)
        }
        
        // Servers
        onServersFetched: {
            loadingServers = false
            homePage.servers = servers
            
            // Check for saved server state and restore if valid
            var savedServerId = SerchatAPI.lastServerId
            if (savedServerId && savedServerId !== "") {
                // Find the saved server in the list
                for (var i = 0; i < servers.length; i++) {
                    var server = servers[i]
                    var serverId = server._id || server.id
                    if (serverId === savedServerId) {
                        // Restore server selection
                        currentServerId = serverId
                        currentServerName = server.name
                        currentServerOwnerId = server.ownerId || ""
                        loadChannels(serverId)
                        return // Exit early, don't do auto-selection
                    }
                }
            }
            
            // Fallback: Auto-select first server if none selected
            if (servers.length > 0 && currentServerId === "") {
                var firstServer = servers[0]
                currentServerId = firstServer._id || firstServer.id
                currentServerName = firstServer.name
                loadChannels(currentServerId)
            }
        }
        
        onServersFetchFailed: {
            loadingServers = false
            console.log("Failed to fetch servers:", error)
        }
        
        // Channels
        onChannelsFetched: {
            if (serverId === currentServerId) {
                loadingChannels = false
                
                // Filter out categories (type === "category") from channels list
                // Categories are fetched separately via getCategories
                var chans = []
                for (var i = 0; i < channels.length; i++) {
                    var item = channels[i]
                    if (item.type !== "category") {
                        chans.push(item)
                    }
                }
                
                // Update the C++ model with channels
                SerchatAPI.channelListModel.setChannels(chans)
                
                // Check for saved channel state and restore if valid
                var savedChannelId = SerchatAPI.lastChannelId
                if (savedChannelId && savedChannelId !== "") {
                    // Find the saved channel in the list
                    for (var j = 0; j < chans.length; j++) {
                        var ch = chans[j]
                        var chId = ch._id || ch.id
                        if (chId === savedChannelId && ch.type === "text") {
                            // Set viewing state BEFORE setting currentChannelId
                            SerchatAPI.viewingDMRecipientId = ""
                            SerchatAPI.viewingServerId = currentServerId
                            SerchatAPI.viewingChannelId = chId
                            
                            // Restore channel selection
                            currentChannelId = chId
                            currentChannelName = ch.name
                            currentChannelType = ch.type
                            loadMessages(currentServerId, currentChannelId)
                            
                            // Set mobile view mode for convergence - always show messages when channel restored
                            mobileViewMode = "messages"
                            
                            return // Exit early, don't do auto-selection
                        }
                    }
                }
                
                // Fallback: Auto-select first text channel
                if (chans.length > 0 && currentChannelId === "") {
                    for (var k = 0; k < chans.length; k++) {
                        if (chans[k].type === "text") {
                            var channel = chans[k]
                            var autoChId = channel._id || channel.id
                            
                            // Set viewing state BEFORE setting currentChannelId
                            SerchatAPI.viewingDMRecipientId = ""
                            SerchatAPI.viewingServerId = currentServerId
                            SerchatAPI.viewingChannelId = autoChId
                            
                            currentChannelId = autoChId
                            currentChannelName = channel.name
                            currentChannelType = channel.type
                            loadMessages(currentServerId, currentChannelId)
                            break
                        }
                    }
                }
            }
        }
        
        onChannelsFetchFailed: {
            if (serverId === currentServerId) {
                loadingChannels = false
                console.log("Failed to fetch channels:", error)
            }
        }
        
        // Categories
        onCategoriesFetched: {
            if (serverId === currentServerId) {
                // Update the C++ model with categories
                SerchatAPI.channelListModel.setCategories(categories)
            }
        }
        
        onCategoriesFetchFailed: {
            if (serverId === currentServerId) {
                console.log("Failed to fetch categories:", error)
            }
        }
        
        // Server Emojis are now handled by C++ EmojiCache
        // Signal handlers removed - cache auto-populates via C++ lambdas
        
        // Messages
        onMessagesFetched: function(requestId, serverId, channelId, fetchedMessages) {
            console.log("[HomePage] Messages fetched for channel:", channelId, "current:", currentChannelId, "count:", fetchedMessages.length)
            if (channelId === currentChannelId) {
                loadingMessages = false
                
                // API returns oldest first, but we need newest first (index 0 = bottom with BottomToTop)
                var reversedMessages = fetchedMessages.slice().reverse()
                
                // Check if this is a pagination request (loading older messages)
                if (SerchatAPI.messageModel.count > 0 && reversedMessages.length > 0) {
                    // This is pagination - append older messages at the end using proper model signals
                    SerchatAPI.messageModel.appendMessages(reversedMessages)
                } else {
                    // Initial load - use appendMessages for correct ordering
                    // With BottomToTop ListView: index 0 = bottom, so we need newest at index 0
                    // reversedMessages is [newest, ..., oldest], appendMessages preserves this order
                    SerchatAPI.messageModel.appendMessages(reversedMessages)
                    
                    // Note: We don't set lastReadMessageId here because when viewing a channel,
                    // all messages are considered read. The C++ clearChannelUnread() handles this.
                }
                console.log("[HomePage] Messages updated, total:", SerchatAPI.messageModel.count)
                
                // Check if there are more messages
                SerchatAPI.messageModel.hasMoreMessages = (fetchedMessages.length >= 50)
            } else {
                console.log("[HomePage] Ignoring messages for old channel:", channelId)
            }
        }
        
        onMessagesFetchFailed: {
            if (channelId === currentChannelId) {
                loadingMessages = false
                console.log("Failed to fetch messages:", error)
            }
        }
        
        onMessageSent: {
            console.log("[HomePage] Message sent via HTTP:", message._id)
            // Use C++ method that handles duplicate detection and temp message replacement
            SerchatAPI.messageModel.addRealMessage(message)
        }

        onMessageSendFailed: {
            console.log("Failed to send message:", error)
            // Use C++ method to remove all temp messages
            SerchatAPI.messageModel.removeAllTempMessages()
        }
        
        // Friends (for DM list)
        onFriendsFetched: {
            console.log("[HomePage] Friends fetched:", friends.length)
            // Transform friends list into DM conversations format
            var conversations = []
            for (var i = 0; i < friends.length; i++) {
                var friend = friends[i]
                conversations.push({
                    recipientId: friend._id || friend.id,
                    recipientName: friend.displayName || friend.username,
                    recipientAvatar: friend.profilePicture ? SerchatAPI.apiBaseUrl + friend.profilePicture : "",
                    lastMessageAt: friend.latestMessageAt || "",
                    customStatus: friend.customStatus
                })
            }
            // Sort by most recent message
            conversations.sort(function(a, b) {
                if (!a.lastMessageAt) return 1
                if (!b.lastMessageAt) return -1
                return new Date(b.lastMessageAt) - new Date(a.lastMessageAt)
            })
            dmConversations = conversations
            
            // Check for saved DM state and restore if valid (only if no server/channel selected)
            var savedDMRecipientId = SerchatAPI.lastDMRecipientId
            if (savedDMRecipientId && savedDMRecipientId !== "" && currentServerId === "" && currentChannelId === "") {
                // Find the saved DM recipient in the friends list
                for (var j = 0; j < friends.length; j++) {
                    var friend = friends[j]
                    var friendId = friend._id || friend.id
                    if (friendId === savedDMRecipientId) {
                        // Set viewing state BEFORE setting currentDMRecipientId
                        SerchatAPI.viewingServerId = ""
                        SerchatAPI.viewingChannelId = ""
                        SerchatAPI.viewingDMRecipientId = friendId
                        
                        // Restore DM selection
                        currentDMRecipientId = friendId
                        currentDMRecipientName = friend.displayName || friend.username
                        currentDMRecipientAvatar = friend.profilePicture ? SerchatAPI.apiBaseUrl + friend.profilePicture : ""
                        loadDMMessages(friendId)
                        
                        // Set mobile view mode for convergence - always show messages when DM restored
                        mobileViewMode = "messages"
                        
                        return // Exit early
                    }
                }
            }
        }
        
        onFriendsFetchFailed: {
            console.log("[HomePage] Failed to fetch friends:", error)
        }
        
        // DM Messages
        onDmMessagesFetched: function(requestId, recipientId, fetchedMessages) {
            console.log("[HomePage] DM Messages fetched for:", recipientId, "current:", currentDMRecipientId, "count:", fetchedMessages.length)
            if (recipientId === currentDMRecipientId) {
                loadingMessages = false
                
                // API returns oldest first, but we need newest first (index 0 = bottom with BottomToTop)
                var reversedMessages = fetchedMessages.slice().reverse()
                
                // Check if this is a pagination request
                if (SerchatAPI.messageModel.count > 0 && reversedMessages.length > 0) {
                    // This is pagination - append older messages at the end using proper model signals
                    SerchatAPI.messageModel.appendMessages(reversedMessages)
                } else {
                    // Initial load - use appendMessages for correct ordering
                    // With BottomToTop ListView: index 0 = bottom, so we need newest at index 0
                    // reversedMessages is [newest, ..., oldest], appendMessages preserves this order
                    SerchatAPI.messageModel.appendMessages(reversedMessages)
                    
                    // Note: We don't set lastReadMessageId here because when viewing a DM,
                    // all messages are considered read. The C++ clearDMUnread() handles this.
                }
                console.log("[HomePage] DM Messages updated, total:", SerchatAPI.messageModel.count)
                
                // Check if there are more messages
                SerchatAPI.messageModel.hasMoreMessages = (fetchedMessages.length >= 50)
            } else {
                console.log("[HomePage] Ignoring DM messages for old recipient:", recipientId)
            }
        }
        
        onDmMessagesFetchFailed: {
            if (recipientId === currentDMRecipientId) {
                loadingMessages = false
                console.log("[HomePage] Failed to fetch DM messages:", error)
            }
        }
        
        onDmMessageSent: {
            console.log("[HomePage] DM Message sent via HTTP:", message._id)
            // Use C++ method that handles duplicate detection and temp message replacement
            SerchatAPI.messageModel.addRealMessage(message)
        }

        onDmMessageSendFailed: {
            console.log("[HomePage] Failed to send DM message:", error)
            // Use C++ method to remove all temp messages
            SerchatAPI.messageModel.removeAllTempMessages()
        }
        
        // Server management
        onServerJoined: {
            console.log("[HomePage] Joined server:", serverId)
            // Refresh servers list
            SerchatAPI.getServers(false)
        }
        
        onServerJoinFailed: {
            console.log("[HomePage] Failed to join server:", error)
        }
        
        onServerCreated: {
            console.log("[HomePage] Created server:", server.name)
            // Refresh servers list
            SerchatAPI.getServers(false)
        }
        
        onServerCreateFailed: {
            console.log("[HomePage] Failed to create server:", error)
        }
        
        // ====================================================================
        // Real-time Socket.IO Events
        // ====================================================================
        
        onSocketConnected: {
            console.log("[HomePage] Socket connected")
            // Join all servers we're a member of
            for (var i = 0; i < servers.length; i++) {
                var serverId = servers[i]._id || servers[i].id
                SerchatAPI.joinServer(serverId)
            }
            
            // Join current channel if any
            if (currentServerId && currentChannelId) {
                SerchatAPI.joinChannel(currentServerId, currentChannelId)
            }
        }
        
        onSocketDisconnected: {
            console.log("[HomePage] Socket disconnected")
        }
        
        onSocketReconnecting: {
            console.log("[HomePage] Socket reconnecting, attempt:", attempt)
        }
        
        onSocketError: {
            console.log("[HomePage] Socket error:", message)
        }
        
        // Real-time server messages
        onServerMessageReceived: {
            console.log("[HomePage] Server message received:", message._id, "channelId:", message.channelId)

            // Only add if it's for the current channel
            var msgChannelId = String(message.channelId || "")
            var currChannelId = String(currentChannelId || "")

            if (msgChannelId === currChannelId && msgChannelId !== "") {
                // Use C++ method that handles duplicate detection and temp message replacement
                SerchatAPI.messageModel.addRealMessage(message)
            }
        }
        
        onServerMessageEdited: {
            console.log("[HomePage] Server message edited:", message._id)
            
            // Update message using C++ model - uses dataChanged signal to preserve scroll
            var msgId = String(message._id || message.id || "")
            SerchatAPI.messageModel.updateMessage(msgId, message)
        }
        
        onServerMessageDeleted: {
            console.log("[HomePage] Server message deleted:", messageId)
            
            // Delete message using C++ model - uses proper remove signals to preserve scroll
            SerchatAPI.messageModel.deleteMessage(String(messageId))
        }
        
        // Channel unread notifications
        onChannelUnread: {
            console.log("[HomePage] Channel unread:", serverId, channelId)
            
            // Update channel-level unread counts
            var newCounts = Object.assign({}, unreadCounts)
            var key = serverId + ":" + channelId
            newCounts[key] = (newCounts[key] || 0) + 1
            unreadCounts = newCounts
        }
        
        // Channel unread state changes (from C++ tracking)
        // This is primarily used for clearing unread state when channel is marked as read
        onChannelUnreadStateChanged: {
            console.log("[HomePage] Channel unread state changed:", serverId, channelId, hasUnread)
            if (!hasUnread) {
                // Clear the unread count when C++ tells us channel is read
                var key = serverId + ":" + channelId
                var newCounts = Object.assign({}, unreadCounts)
                newCounts[key] = 0
                unreadCounts = newCounts
            }
            // Note: We don't set counts here for hasUnread=true because
            // onChannelUnread handles incrementing the count properly
        }
        
        // Server unread state changes (any channel in server has unread)
        onServerUnreadStateChanged: {
            console.log("[HomePage] Server unread state changed:", serverId, hasUnread)
            // Force UI update by triggering servers refresh
            // The ServerListView will check hasServerUnread() for each server
            homePage.servers = homePage.servers.slice()  // Create new array reference to trigger binding update
        }
        
        // DM unread notifications
        onDmUnread: {
            console.log("[HomePage] DM unread:", peer, count)
            
            var newCounts = Object.assign({}, dmUnreadCounts)
            newCounts[peer] = count
            dmUnreadCounts = newCounts
        }
        
        // Direct message events
        onDirectMessageReceived: {
            console.log("[HomePage] DM received:", message._id)
            
            // If currently in DM with this user, add message
            var senderId = String(message.senderId || "")
            var receiverId = String(message.receiverId || "")
            var currRecipient = String(currentDMRecipientId || "")
            
            if (currRecipient !== "" && (currRecipient === senderId || currRecipient === receiverId)) {
                var newId = String(message._id || message.id || "")
                var isDuplicate = SerchatAPI.messageModel.hasMessage(newId)
                
                if (!isDuplicate) {
                    // Add new message using C++ model - uses proper insert signals
                    SerchatAPI.messageModel.prependMessage(message)
                    console.log("[HomePage] Added DM to list, new count:", SerchatAPI.messageModel.count)
                }
            }
        }
        
        // User presence
        onUserOnline: {
            console.log("[HomePage] User online:", username)
            // TODO: Update user status in UI
        }
        
        onUserOffline: {
            console.log("[HomePage] User offline:", username)
            // TODO: Update user status in UI
        }
        
        // Typing indicators
        onUserTyping: {
            if (serverId === currentServerId && channelId === currentChannelId) {
                console.log("[HomePage] User typing in channel:", username)
                // TODO: Show typing indicator in MessageView
            }
        }
        
        onDmTyping: {
            console.log("[HomePage] User typing in DM:", username)
            // TODO: Show typing indicator in DM view
        }
        
        // Channel updates
        onChannelCreated: {
            console.log("[HomePage] Channel created in server:", serverId)
            if (serverId === currentServerId) {
                // Add the new channel to the C++ model
                SerchatAPI.channelListModel.addChannel(channel)
            }
        }
        
        onChannelDeleted: {
            console.log("[HomePage] Channel deleted:", channelId)
            if (serverId === currentServerId) {
                // If we're viewing the deleted channel, go back
                if (channelId === currentChannelId) {
                    currentChannelId = ""
                    currentChannelName = ""
                    SerchatAPI.messageModel.clear()
                }
                // Remove from the C++ model
                SerchatAPI.channelListModel.removeChannel(channelId)
            }
        }
        
        onChannelUpdated: {
            console.log("[HomePage] Channel updated in server:", serverId)
            if (serverId === currentServerId) {
                // Update in the C++ model
                var chId = channel._id || channel.id
                SerchatAPI.channelListModel.updateChannel(chId, channel)
            }
        }
        
        // Category updates
        onCategoryCreated: {
            console.log("[HomePage] Category created in server:", serverId)
            if (serverId === currentServerId) {
                SerchatAPI.channelListModel.addCategory(category)
            }
        }
        
        onCategoryUpdated: {
            console.log("[HomePage] Category updated in server:", serverId)
            if (serverId === currentServerId) {
                var catId = category._id || category.id
                SerchatAPI.channelListModel.updateCategory(catId, category)
            }
        }
        
        onCategoryDeleted: {
            console.log("[HomePage] Category deleted:", categoryId)
            if (serverId === currentServerId) {
                SerchatAPI.channelListModel.removeCategory(categoryId)
            }
        }
        
        // Reaction updates
        onReactionAdded: {
            console.log("[HomePage] Reaction added to message:", messageId)
            updateMessageReactions(messageId, reactions)
        }
        
        onReactionRemoved: {
            console.log("[HomePage] Reaction removed from message:", messageId)
            updateMessageReactions(messageId, reactions)
        }
        
        // Friend events
        onFriendAdded: {
            console.log("[HomePage] Friend added:", friendData.username)
            // TODO: Update friends list if visible
            // Could refresh DM conversations list
        }
        
        onFriendRemoved: {
            console.log("[HomePage] Friend removed:", username)
            // TODO: Update friends list if visible
            // If currently in DM with this friend, may want to notify user
        }
        
        onIncomingRequestAdded: {
            console.log("[HomePage] Incoming friend request from:", request.from)
            // TODO: Show notification or update friend requests badge
        }
        
        onIncomingRequestRemoved: {
            console.log("[HomePage] Friend request removed from:", from)
            // TODO: Update friend requests list if visible
        }
        
        // Server management events
        onServerUpdated: {
            console.log("[HomePage] Server updated:", serverId)
            SerchatAPI.serversModel.updateItem(serverId, server)
            // Update local state if it's the current server
            if (serverId === currentServerId && server.name) {
                currentServerName = server.name
            }
        }
        
        onServerDeleted: {
            console.log("[HomePage] Server deleted:", serverId)
            SerchatAPI.serversModel.removeItem(serverId)
            // If we're viewing the deleted server, go back to server list
            if (serverId === currentServerId) {
                currentServerId = ""
                currentServerName = ""
                currentChannelId = ""
                currentChannelName = ""
                SerchatAPI.channelListModel.clear()
                SerchatAPI.messageModel.clear()
            }
        }
        
        onServerOwnershipTransferred: {
            console.log("[HomePage] Server ownership transferred:", serverId, 
                        "from", previousOwnerId, "to", newOwnerId)
            // Update the server's owner in the model
            SerchatAPI.serversModel.updateItemProperty(serverId, "ownerId", newOwnerId)
        }
        
        // Role events
        onRoleCreated: {
            console.log("[HomePage] Role created in server:", serverId, role.name)
            // TODO: Update roles model if we have one
        }
        
        onRoleUpdated: {
            console.log("[HomePage] Role updated in server:", serverId, role.name)
            // TODO: Update roles model if we have one
            // May need to update member list colors if role colors changed
        }
        
        onRoleDeleted: {
            console.log("[HomePage] Role deleted in server:", serverId, roleId)
            // TODO: Update roles model if we have one
        }
        
        onRolesReordered: {
            console.log("[HomePage] Roles reordered in server:", serverId)
            // TODO: Update roles model order if we have one
        }
        
        // Member events (from REST operations)
        onMemberAdded: {
            console.log("[HomePage] Member added to server:", serverId, userId)
            if (serverId === currentServerId) {
                // Refresh members list to include the new member
                SerchatAPI.getServerMembers(serverId, false)
            }
        }
        
        onMemberRemoved: {
            console.log("[HomePage] Member removed from server:", serverId, userId)
            if (serverId === currentServerId) {
                SerchatAPI.membersModel.removeItem(userId)
            }
        }
        
        onMemberUpdated: {
            console.log("[HomePage] Member updated in server:", serverId, userId)
            if (serverId === currentServerId) {
                SerchatAPI.membersModel.updateItem(userId, member)
            }
        }
        
        // Permission events
        onChannelPermissionsUpdated: {
            console.log("[HomePage] Channel permissions updated:", serverId, channelId)
            if (serverId === currentServerId) {
                // Update channel in the model with new permissions
                var channel = SerchatAPI.channelListModel.getChannel(channelId)
                if (channel) {
                    channel.permissions = permissions
                    SerchatAPI.channelListModel.updateChannel(channelId, channel)
                }
            }
        }
        
        onCategoryPermissionsUpdated: {
            console.log("[HomePage] Category permissions updated:", serverId, categoryId)
            if (serverId === currentServerId) {
                // Update category in the model with new permissions
                var category = SerchatAPI.channelListModel.getCategory(categoryId)
                if (category) {
                    category.permissions = permissions
                    SerchatAPI.channelListModel.updateCategory(categoryId, category)
                }
            }
        }
        
        // User profile events
        onUserUpdated: function(userId, updates) {
            console.log("[HomePage] User updated:", userId)
            // TODO: Update user info in member list or elsewhere if visible
        }
        
        onUserBannerUpdated: {
            console.log("[HomePage] User banner updated:", username)
            // TODO: Update user banner if profile is visible
        }
        
        onUsernameChanged: {
            console.log("[HomePage] Username changed:", oldUsername, "->", newUsername)
            // TODO: Update username in all relevant places
        }
        
        // Admin events
        onWarningReceived: {
            console.log("[HomePage] Warning received:", warning.reason)
            // TODO: Show warning dialog to user
        }
        
        onAccountDeleted: {
            console.log("[HomePage] Account deleted:", reason)
            // Force logout
            SerchatAPI.logout()
        }
        
        // Emoji events
        onEmojiUpdated: {
            console.log("[HomePage] Emojis updated for server:", serverId)
            if (serverId === currentServerId) {
                // Refresh server emojis
                SerchatAPI.getServerEmojis(serverId, false)
            }
        }
    }
    
    // ========================================================================
    // Data Loading Functions
    // ========================================================================
    
    function loadServers() {
        loadingServers = true
        SerchatAPI.getServers()
    }
    
    function loadDMConversations() {
        // Load friends list which serves as DM conversations
        SerchatAPI.getFriends()
    }
    
    function loadChannels(serverId) {
        // Clear unread divider for current channel when leaving
        if (currentServerId && currentChannelId) {
            SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
            SerchatAPI.leaveChannel(currentServerId, currentChannelId)
        }

        // Clear viewing state when navigating away from a channel view
        SerchatAPI.viewingServerId = ""
        SerchatAPI.viewingChannelId = ""
        SerchatAPI.viewingDMRecipientId = ""

        loadingChannels = true
        SerchatAPI.messageModel.clear()  // Clear messages when loading new server
        SerchatAPI.channelListModel.clear()  // Clear channel list model
        currentChannelId = ""
        currentChannelName = ""

        // Fetch both channels and categories for the server
        SerchatAPI.getChannels(serverId)
        SerchatAPI.getCategories(serverId)

        // Also fetch server emojis for custom emoji rendering
        SerchatAPI.getServerEmojis(serverId)
    }
    
    function loadMessages(serverId, channelId) {
        if (!serverId || !channelId) return
        
        loadingMessages = true
        
        // Clear any DM viewing state and set channel viewing state
        // This tells C++ to auto-mark incoming messages as read
        SerchatAPI.viewingDMRecipientId = ""
        SerchatAPI.viewingServerId = serverId
        SerchatAPI.viewingChannelId = channelId
        
        // Set channel context and clear messages using proper model signals
        SerchatAPI.messageModel.setChannel(serverId, channelId)
        
        // Join the channel room for real-time updates
        SerchatAPI.joinChannel(serverId, channelId)
        
        // Mark channel as read on the server (sends mark_channel_read event)
        SerchatAPI.markChannelAsRead(serverId, channelId)

        SerchatAPI.getMessages(serverId, channelId, 50, "")
    }
    
    function loadOlderMessages() {
        var model = SerchatAPI.messageModel
        if (loadingMessages || !model.hasMoreMessages || model.count === 0) return
        
        loadingMessages = true
        
        // Get the oldest message ID using C++ model method
        var oldestId = model.oldestMessageId()
        SerchatAPI.getMessages(currentServerId, currentChannelId, 50, oldestId)
    }
    
    function sendMessageToChannel(text, replyToId) {
        if (!currentServerId || !currentChannelId || !text) return
        
        // Optimistically add message to view using C++ model
        var newMessage = {
            _id: "temp_" + Date.now(),
            serverId: currentServerId,
            channelId: currentChannelId,
            senderId: currentUserId,
            text: text,
            createdAt: new Date().toISOString(),
            replyToId: replyToId || null
        }
        
        // Use model method - will use proper insert signals
        SerchatAPI.messageModel.prependMessage(newMessage)
        
        // Send via API
        SerchatAPI.sendMessage(currentServerId, currentChannelId, text, replyToId || "")
    }
    
    function loadDMMessages(recipientId) {
        if (!recipientId) return
        
        loadingMessages = true
        
        // Clear any channel viewing state and set DM viewing state
        // This tells C++ to auto-mark incoming messages as read
        SerchatAPI.viewingServerId = ""
        SerchatAPI.viewingChannelId = ""
        SerchatAPI.viewingDMRecipientId = recipientId
        
        // Set DM mode and clear messages using proper model signals
        SerchatAPI.messageModel.setDMRecipient(recipientId)
        
        // Mark DM as read when viewing
        SerchatAPI.clearDMUnread(recipientId)
        
        // Fetch DM messages from API
        SerchatAPI.getDMMessages(recipientId, 50, "")
    }
    
    function loadOlderDMMessages() {
        var model = SerchatAPI.messageModel
        if (loadingMessages || !model.hasMoreMessages || model.count === 0 || !currentDMRecipientId) return
        
        loadingMessages = true
        
        // Get the oldest message ID using C++ model method
        var oldestId = model.oldestMessageId()
        SerchatAPI.getDMMessages(currentDMRecipientId, 50, oldestId)
    }
    
    function sendDMMessageToUser(text, replyToId) {
        if (!currentDMRecipientId || !text) return
        
        // Optimistically add message to view using C++ model
        var newMessage = {
            _id: "temp_" + Date.now(),
            senderId: currentUserId,
            receiverId: currentDMRecipientId,
            text: text,
            createdAt: new Date().toISOString(),
            pending: true,
            replyToId: replyToId || null
        }
        
        // Use model method - will use proper insert signals
        SerchatAPI.messageModel.prependMessage(newMessage)
        
        // Send via API
        SerchatAPI.sendDMMessage(currentDMRecipientId, text, replyToId || "")
    }
    
    // Open DM with a specific user (can be called from ProfilePage)
    function openDMWithUser(recipientId, recipientName, recipientAvatar) {
        // Clear unread divider for channel when leaving
        if (currentServerId && currentChannelId) {
            SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
            SerchatAPI.leaveChannel(currentServerId, currentChannelId)
        }

        // Set viewing state BEFORE setting currentDMRecipientId
        SerchatAPI.viewingServerId = ""
        SerchatAPI.viewingChannelId = ""
        SerchatAPI.viewingDMRecipientId = recipientId

        // Set DM state
        currentDMRecipientId = recipientId
        currentDMRecipientName = recipientName
        currentDMRecipientAvatar = recipientAvatar

        // Clear server/channel state
        currentChannelId = ""
        currentChannelName = ""
        currentServerId = ""
        currentServerName = ""

        loadDMMessages(recipientId)

        if (isSmallScreen) {
            mobileViewMode = "messages"
        }
    }
    
    // Update reactions for a message (preserves scroll position via C++ model)
    function updateMessageReactions(messageId, newReactions) {
        var targetId = String(messageId)
        console.log("[HomePage] updateMessageReactions - Updating message:", targetId)
        
        // Use C++ model's updateReactions method - uses dataChanged signal to preserve scroll
        var success = SerchatAPI.messageModel.updateReactions(targetId, newReactions)
        if (success) {
            console.log("[HomePage] Updated reactions for message:", targetId, "new reactions count:", newReactions.length)
        } else {
            console.log("[HomePage] Message not found for reaction update:", targetId)
        }
    }
    
    // Note: Channel room joining is handled in loadMessages() function
    
    // ========================================================================
    // Dialogs
    // ========================================================================
    
    // Create DM dialog
    Components.CreateDMDialog {
        id: createDMDialog
        anchors.fill: parent
        
        onConversationStarted: {
            createDMDialog.opened = false

            // Clear unread divider for channel when leaving
            if (currentServerId && currentChannelId) {
                SerchatAPI.clearFirstUnreadMessageId(currentServerId, currentChannelId)
                SerchatAPI.leaveChannel(currentServerId, currentChannelId)
            }

            // Set viewing state BEFORE setting currentDMRecipientId
            SerchatAPI.viewingServerId = ""
            SerchatAPI.viewingChannelId = ""
            SerchatAPI.viewingDMRecipientId = recipientId

            // Set DM state
            currentDMRecipientId = recipientId
            currentDMRecipientName = recipientName
            currentDMRecipientAvatar = recipientAvatar

            // Clear channel state
            currentChannelId = ""
            currentChannelName = ""
            currentServerId = ""
            currentServerName = ""

            loadDMMessages(recipientId)

            if (isSmallScreen) {
                mobileViewMode = "messages"
            }
        }
    }
    
    // ========================================================================
    // Initialization
    // ========================================================================
    
    Component.onCompleted: {
        // Fetch user profile
        SerchatAPI.getMyProfile()
        
        // Load servers
        loadServers()
        
        // Load DM conversations (friends list) for potential restore
        loadDMConversations()
        
        // Load all emojis from all servers for cross-server emoji rendering
        SerchatAPI.getAllEmojis()
    }
}
